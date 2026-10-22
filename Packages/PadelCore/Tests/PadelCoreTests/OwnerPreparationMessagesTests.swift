import Foundation
import Testing
@testable import PadelCore

private func preparationValue(stroke: RecordingDrill = .forehandGroundstroke, arm: PlayingArm = .right,
                              authority: OwnerPracticeIdentity? = nil) throws -> OwnerPreparation {
    let owner = try authority ?? ownerTestIdentity()
    let draft = try PracticeSetupDraft(originInstallationEpoch: owner.phoneInstallationEpoch,
        preparationID: UUID(), revision: 1, preferences: PracticeSetupPreferences(
            currentRacketArm: arm, usualHand: .right, intendedDrill: stroke))
    return try OwnerPreparation(authority: owner, practiceID: ownerTestPractice, draft: draft)
}

@Suite struct OwnerPreparationMessagesTests {
    @Test func literalDiscoveryWireAndStrictNoncanonicalRejection() throws {
        let requestID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let phone = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let message = OwnerPreparationMessage.statusRequest(requestID: requestID, phoneEpoch: phone)
        let literal = Data("{\"kind\":\"PSLOwnerSetup2.statusRequest\",\"phoneEpoch\":\"20000000-0000-0000-0000-000000000002\",\"requestID\":\"10000000-0000-0000-0000-000000000001\",\"version\":2}".utf8)
        #expect(try OwnerPreparationCodec.encode(message) == literal)
        #expect(try OwnerPreparationCodec.decode(literal) == message)
        for altered in [
            Data(" ".utf8) + literal,
            Data(String(decoding: literal, as: UTF8.self).replacingOccurrences(of: "\"version\":2", with: "\"version\":3").utf8),
            Data(String(decoding: literal, as: UTF8.self).replacingOccurrences(of: "\"version\":2", with: "\"unknown\":0,\"version\":2").utf8),
            Data(String(decoding: literal, as: UTF8.self).replacingOccurrences(of: "\"version\":2", with: "\"version\":2,\"version\":2").utf8),
            Data(repeating: 32, count: OwnerPreparationCodec.maximumBytes + 1)
        ] {
            #expect(throws: (any Error).self) { try OwnerPreparationCodec.decode(altered) }
        }
    }

    @Test func bothManualStrokesAndArmsBindExactOwnerPracticeAndDraft() throws {
        for stroke in [RecordingDrill.forehandGroundstroke, .backhandGroundstroke] {
            for arm in [PlayingArm.left, .right] {
                let value = try preparationValue(stroke: stroke, arm: arm)
                #expect(value.draft.preferences.currentRacketArm == arm)
                #expect(value.draft.preferences.intendedDrill == stroke)
                let message = OwnerPreparationMessage.draft(value)
                #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(message)) == message)
            }
        }
        #expect(throws: (any Error).self) { try preparationValue(stroke: .serve) }
        let owner = try ownerTestIdentity()
        let withdrawn = try owner.applying(OwnerConsentDecision.withdraw(for: owner, decisionID: UUID(), confirmedAtUnixSeconds: 2))
        #expect(throws: (any Error).self) { try preparationValue(authority: withdrawn) }
        let wrongPhone = try PracticeSetupDraft(originInstallationEpoch: UUID(), preparationID: UUID(), revision: 1,
            preferences: PracticeSetupPreferences(currentRacketArm: .right, usualHand: .right, intendedDrill: .forehandGroundstroke))
        #expect(throws: (any Error).self) { try OwnerPreparation(authority: owner, practiceID: UUID(), draft: wrongPhone) }
    }

    @Test func acceptanceRequiresExactRequestOwnerPracticeAndBothGenerations() throws {
        let value = try preparationValue()
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: ownerTestGenerations, preparation: value.identity)
        let request = OwnerPreparationMessage.prepare(correlation: correlation, preparation: value)
        let observation = try OwnerPreparationObservation(watchEpoch: ownerTestWatch, generations: ownerTestGenerations,
            observedAtUnixSeconds: 5, state: .awaitingConfirmation, authority: ownerTestIdentity(), acceptedCurrent: value.identity)
        let receipt = OwnerPreparationMessage.receipt(correlation: correlation, disposition: .acceptedCurrent, observation: observation)
        #expect(receipt.isReply(to: request))
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(receipt)) == receipt)
        let changed = OwnerPreparationCorrelation(requestID: UUID(), generations: ownerTestGenerations, preparation: value.identity)
        #expect(!receipt.isReply(to: .prepare(correlation: changed, preparation: value)))
        let otherGenerations = PracticeSetupGenerations(runtimeGeneration: UUID(), preparationGeneration: ownerTestGenerations.preparationGeneration)
        let stale = OwnerPreparationCorrelation(requestID: correlation.requestID, generations: otherGenerations, preparation: value.identity)
        #expect(!receipt.isReply(to: .prepare(correlation: stale, preparation: value)))
        let otherPractice = try OwnerPreparation(authority: ownerTestIdentity(), practiceID: UUID(), draft: value.draft)
        #expect(throws: (any Error).self) {
            try OwnerPreparationCodec.encode(.prepare(correlation: correlation, preparation: otherPractice))
        }
        #expect(throws: (any Error).self) {
            try OwnerPreparationObservation(watchEpoch: UUID(), generations: ownerTestGenerations,
                observedAtUnixSeconds: 5, state: .idle, authority: ownerTestIdentity())
        }
    }

    @Test func retirementRequiresRotatedPreparationAndClearedAcceptance() throws {
        let value = try preparationValue()
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: ownerTestGenerations, preparation: value.identity)
        let request = OwnerPreparationMessage.retire(correlation: correlation, reason: .endPractice)
        let rotated = PracticeSetupGenerations(runtimeGeneration: ownerTestGenerations.runtimeGeneration, preparationGeneration: UUID())
        let advanced = try ownerTestIdentity().advancingRevision(expectedRevision: 1)
        let observation = try OwnerPreparationObservation(watchEpoch: ownerTestWatch, generations: rotated,
            observedAtUnixSeconds: 8, state: .idle, authority: advanced)
        let receipt = OwnerPreparationMessage.receipt(correlation: correlation, disposition: .retired,
            observation: observation, retirementReason: .endPractice)
        #expect(receipt.isReply(to: request))
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(receipt)) == receipt)
        #expect(!receipt.isReply(to: .prepare(correlation: correlation, preparation: value)))
        #expect(!receipt.isReply(to: .retire(correlation: correlation, reason: .cancelPreparation)))
        let cancel = OwnerPreparationMessage.receipt(correlation: correlation, disposition: .retired,
            observation: observation, retirementReason: .cancelPreparation)
        #expect(!cancel.isReply(to: request))
        #expect(cancel.isReply(to: .retire(correlation: correlation, reason: .cancelPreparation)))
        #expect(throws: (any Error).self) {
            try OwnerPreparationCodec.encode(.receipt(correlation: correlation, disposition: .retired, observation: observation))
        }
        let unchanged = try OwnerPreparationObservation(watchEpoch: ownerTestWatch, generations: ownerTestGenerations,
            observedAtUnixSeconds: 8, state: .idle, authority: ownerTestIdentity())
        #expect(throws: (any Error).self) {
            try OwnerPreparationCodec.encode(.receipt(correlation: correlation, disposition: .retired,
                observation: unchanged, retirementReason: .endPractice))
        }
    }

    @Test func explicitAuthorityCommandsReplayOnlyTheVerifiedTransition() throws {
        let owner = try ownerTestIdentity()
        let enroll = try OwnerAuthorityMutation.enrollment(owner)
        #expect(try enroll.resolve(from: nil) == owner)
        #expect(try enroll.resolve(from: nil) == owner)
        #expect(throws: (any Error).self) { try enroll.resolve(from: owner) }
        let disable = try OwnerAuthorityMutation.heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        let disabled = try disable.resolve(from: owner)
        #expect(!disabled.heartRateConsent)
        #expect(try disable.resolve(from: owner) == disabled)
        #expect(throws: (any Error).self) { try disable.resolve(from: disabled) }
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: disabled, decisionID: UUID(), confirmedAtUnixSeconds: 1)
        let withdrawn = try withdrawal.resolve(from: disabled)
        #expect(!withdrawn.isCollectionAllowed)
        #expect(throws: (any Error).self) { try enroll.resolve(from: withdrawn) }
        #expect(throws: (any Error).self) { try disable.resolve(from: withdrawn) }
        let renewed = try OwnerAuthorityMutation.reconsent(from: withdrawn, includesHeartRate: false,
            acknowledgesWithdrawal: true, decisionID: UUID(), confirmedAtUnixSeconds: 0)
        #expect(try renewed.resolve(from: withdrawn).isCollectionAllowed)
        let message = OwnerPreparationMessage.mutate(requestID: UUID(), generations: ownerTestGenerations, mutation: renewed)
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(message)) == message)
    }

    @Test func maximumHistoryFitsWireWithoutRepeatingFullIdentities() throws {
        var owner = try ownerTestIdentity()
        for _ in 1..<126 {
            owner = try owner.applying(OwnerConsentDecision.heartRate(for: owner, allowed: true,
                decisionID: UUID(), confirmedAtUnixSeconds: 5, policyDigest: OwnerPracticePolicy.digest))
        }
        let disable = try OwnerAuthorityMutation.heartRate(from: owner, allowed: false,
            decisionID: UUID(), confirmedAtUnixSeconds: 4)
        let disabled = try disable.resolve(from: owner)
        let withdrawal = try OwnerAuthorityMutation.withdraw(from: disabled, decisionID: UUID(), confirmedAtUnixSeconds: 3)
        let withdrawn = try withdrawal.resolve(from: disabled)
        #expect(withdrawn.consentGeneration == 128)
        for mutation in [disable, withdrawal] {
            let bytes = try OwnerPreparationCodec.encode(.mutate(requestID: UUID(), generations: ownerTestGenerations, mutation: mutation))
            #expect(bytes.count <= 4_096)
            #expect(try OwnerPreparationCodec.decode(bytes).mutation == mutation)
        }
        let observation = try OwnerPreparationObservation(watchEpoch: ownerTestWatch, generations: ownerTestGenerations,
            observedAtUnixSeconds: 6, state: .idle, authority: withdrawn)
        let status = OwnerPreparationMessage.status(requestID: UUID(), phoneEpoch: ownerTestPhone, observation: observation)
        let bytes = try OwnerPreparationCodec.encode(status)
        #expect(bytes.count <= 32_768)
        #expect(try OwnerPreparationCodec.decode(bytes) == status)
    }

    @Test func explicitTransitionAndAckAreBoundedAndSemanticallyValidated() throws {
        let mutation = try OwnerAuthorityMutation.enrollment(ownerTestIdentity())
        let transition = try OwnerAuthorityTransition(sequence: 1, mutation: mutation)
        let ack = try OwnerAuthorityAcknowledgement(transition: transition)
        #expect(ack.matches(transition))
        #expect(try transition.encoded().count <= 4_096)
        #expect(try OwnerAuthorityTransition.decode(transition.encoded()) == transition)
        for message in [OwnerPreparationMessage.transition(transition), .acknowledge(ack)] {
            #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(message)) == message)
        }
        #expect(throws: (any Error).self) { try OwnerAuthorityTransition(sequence: 0, mutation: mutation) }
        #expect(throws: (any Error).self) { try OwnerAuthorityTransition(sequence: 2, mutation: mutation) }
        let invalidAck = try changingJSON(PracticeSetupJSON.encode(ack)) { $0["sequence"] = 0 }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(OwnerAuthorityAcknowledgement.self, from: invalidAck) }
        let invalidDigest = try changingJSON(PracticeSetupJSON.encode(ack)) { $0["transitionDigest"] = String(repeating: "A", count: 64) }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(OwnerAuthorityAcknowledgement.self, from: invalidDigest) }
    }

    @Test func appliedReplyRequiresExactCommandRequestAndGenerations() throws {
        let owner = try ownerTestIdentity()
        let command = try OwnerAuthorityMutation.advance(from: owner, mutationID: UUID())
        let transition = try OwnerAuthorityTransition(sequence: 2, mutation: command)
        let requestID = UUID()
        let request = OwnerPreparationMessage.mutate(requestID: requestID, generations: ownerTestGenerations, mutation: command)
        let applied = OwnerPreparationMessage.applied(requestID: requestID, generations: ownerTestGenerations, transition: transition)
        #expect(applied.isReply(to: request))
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(applied)) == applied)
        let alternative = try OwnerAuthorityMutation.advance(from: owner, mutationID: UUID())
        #expect(!applied.isReply(to: .mutate(requestID: requestID, generations: ownerTestGenerations, mutation: alternative)))
        #expect(!applied.isReply(to: .mutate(requestID: UUID(), generations: ownerTestGenerations, mutation: command)))
        #expect(!applied.isReply(to: .mutate(requestID: requestID,
            generations: PracticeSetupGenerations(runtimeGeneration: ownerTestGenerations.runtimeGeneration, preparationGeneration: UUID()), mutation: command)))
        #expect(!OwnerPreparationMessage.transition(transition).isReply(to: request))
    }

    @Test func replayIsOneContiguousTransitionAfterAnExactPeerCursor() throws {
        let owner = try ownerTestIdentity()
        let first = try OwnerAuthorityTransition(sequence: 1, mutation: .enrollment(owner))
        let ack = try OwnerAuthorityAcknowledgement(transition: first)
        let start = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID, phoneEpoch: ownerTestPhone, watchEpoch: ownerTestWatch)
        let cursor = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID, phoneEpoch: ownerTestPhone, watchEpoch: ownerTestWatch, after: ack)
        let next = try OwnerAuthorityTransition(sequence: 2, mutation: .advance(from: owner, mutationID: UUID()))
        let requestID = UUID()
        let request = OwnerPreparationMessage.replay(requestID: requestID, cursor: cursor)
        let response = OwnerPreparationMessage.replayResult(requestID: requestID, cursor: cursor, transition: next)
        #expect(response.isReply(to: request))
        #expect(!response.isReply(to: .replay(requestID: requestID, cursor: start)))
        for message in [request, response, .replayResult(requestID: requestID, cursor: cursor, transition: nil),
                        .replayResult(requestID: UUID(), cursor: start, transition: first)] {
            #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(message)) == message)
        }
        #expect(throws: (any Error).self) { try OwnerPreparationCodec.encode(.replayResult(requestID: requestID, cursor: start, transition: next)) }
        #expect(throws: (any Error).self) { try OwnerPreparationCodec.encode(.replayResult(requestID: requestID, cursor: cursor, transition: first)) }
        #expect(throws: (any Error).self) {
            try OwnerAuthorityReplayCursor(ownerID: UUID(), phoneEpoch: ownerTestPhone, watchEpoch: ownerTestWatch, after: ack)
        }
        let alternate = try OwnerAuthorityTransition(sequence: 1, mutation: .enrollment(ownerTestIdentity(heartRate: false)))
        let wrongTip = try OwnerAuthorityReplayCursor(ownerID: owner.ownerID, phoneEpoch: ownerTestPhone, watchEpoch: ownerTestWatch,
            after: OwnerAuthorityAcknowledgement(transition: alternate))
        #expect(throws: (any Error).self) { try OwnerPreparationCodec.encode(.replayResult(requestID: requestID, cursor: wrongTip, transition: next)) }
    }

    @Test func failureCorrelatesTheEntireRequestIncludingPeerAndGeneration() throws {
        let requestID = UUID()
        let request = OwnerPreparationMessage.statusRequest(requestID: requestID, phoneEpoch: ownerTestPhone)
        let failure = try OwnerPreparationMessage.failure(replyingTo: request, code: .storageFailure)
        #expect(failure.isReply(to: request))
        #expect(!failure.isReply(to: .statusRequest(requestID: requestID, phoneEpoch: UUID())))
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(failure)) == failure)
        #expect(throws: (any Error).self) { try OwnerPreparationMessage.failure(replyingTo: failure, code: .invalidRequest) }
    }

    @Test func restrictionsRebaseOnlyAcrossVerifiedRevisionChangesWithSameBarrier() throws {
        let owner = try ownerTestIdentity()
        let decisionID = UUID()
        let restriction = try OwnerAuthorityMutation.withdraw(from: owner, decisionID: decisionID, confirmedAtUnixSeconds: 1)
        let advanced = try owner.advancingRevision(expectedRevision: 1)
        let rebased = try restriction.rebasingRestriction(afterVerifiedRevisionOnlyChangesTo: advanced)
        #expect(rebased.id == decisionID)
        #expect(try rebased.resolve(from: advanced).revision == 3)
        #expect(throws: (any Error).self) { try restriction.resolve(from: advanced) }
        let disabled = try OwnerAuthorityMutation.heartRate(from: owner, allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 2).resolve(from: owner)
        #expect(throws: (any Error).self) { try restriction.rebasingRestriction(afterVerifiedRevisionOnlyChangesTo: disabled) }
        let grant = try OwnerAuthorityMutation.heartRate(from: owner, allowed: true, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        #expect(throws: (any Error).self) { try grant.rebasingRestriction(afterVerifiedRevisionOnlyChangesTo: advanced) }
        let renewed = try OwnerAuthorityMutation.reconsent(from: restriction.resolve(from: owner), includesHeartRate: true,
            acknowledgesWithdrawal: true, decisionID: UUID(), confirmedAtUnixSeconds: 0)
        #expect(throws: (any Error).self) { try renewed.rebasingRestriction(afterVerifiedRevisionOnlyChangesTo: advanced) }
    }

    @Test func resealedCommandsCannotChangeAuthorityOrSmuggleInconsistentFields() throws {
        let owner = try ownerTestIdentity()
        let command = try OwnerAuthorityMutation.withdraw(from: owner, decisionID: UUID(), confirmedAtUnixSeconds: 2)
        let bytes = try command.encoded()
        for field in ["ownerID", "phoneEpoch", "watchEpoch", "afterDigest", "beforeDigest"] {
            let altered = try resealingCommand(bytes) {
                $0[field] = field.hasSuffix("Digest") ? String(repeating: "0", count: 64) : UUID().uuidString
            }
            #expect(throws: (any Error).self) { try OwnerAuthorityMutation.decode(altered).resolve(from: owner) }
        }
        for fields: [String: Any] in [["policyDigest": String(repeating: "0", count: 64)], ["heartRate": true],
                                     ["revision": 0], ["consentGeneration": 129], ["withdrawalBarrier": -1], ["confirmedAt": -1],
                                     ["practiceID": UUID().uuidString], ["acknowledgesWithdrawal": true], ["unknown": 0]] {
            let altered = try resealingCommand(bytes) { $0.merge(fields, uniquingKeysWith: { _, new in new }) }
            #expect(throws: (any Error).self) { try OwnerAuthorityMutation.decode(altered) }
        }
        let retire = try OwnerAuthorityMutation.retirePractice(from: owner, practiceID: ownerTestPractice, mutationID: UUID())
        #expect(retire.retiredPracticeID == ownerTestPractice)
        #expect(try retire.resolve(from: owner) == owner.advancingRevision(expectedRevision: 1))
        let initial = try OwnerAuthorityMutation.enrollment(owner)
        #expect(throws: (any Error).self) { try OwnerAuthorityMutation.enrollment(retire.resolve(from: owner)) }
        #expect(throws: (any Error).self) { try OwnerAuthorityMutation.decode(initial.encoded() + Data(" ".utf8)) }
    }

    @Test func statusAcceptanceAndRetirementRejectForeignOrUnadvancedAuthority() throws {
        let value = try preparationValue()
        let correlation = OwnerPreparationCorrelation(requestID: UUID(), generations: ownerTestGenerations, preparation: value.identity)
        let rotated = PracticeSetupGenerations(runtimeGeneration: ownerTestGenerations.runtimeGeneration, preparationGeneration: UUID())
        let observation = try OwnerPreparationObservation(watchEpoch: ownerTestWatch, generations: rotated,
            observedAtUnixSeconds: 4, state: .idle, authority: value.authority)
        #expect(throws: (any Error).self) { try OwnerPreparationCodec.encode(.receipt(correlation: correlation, disposition: .retired,
            observation: observation, retirementReason: .endPractice)) }
        #expect(throws: (any Error).self) { try OwnerPreparationCodec.encode(.status(requestID: UUID(), phoneEpoch: UUID(), observation: observation)) }
        #expect(throws: (any Error).self) { try OwnerPreparationObservation(watchEpoch: ownerTestWatch, generations: ownerTestGenerations,
            observedAtUnixSeconds: 4, state: .unavailable, authority: value.authority, acceptedCurrent: value.identity) }
        let invalidIdentity = try changingJSON(PracticeSetupJSON.encode(value.identity)) { $0["authorityRevision"] = 0 }
        #expect(throws: (any Error).self) { try JSONDecoder().decode(OwnerPreparationIdentity.self, from: invalidIdentity) }
    }
}

private func changingJSON(_ bytes: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    change(&object)
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
}

private func resealingCommand(_ bytes: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
    var envelope = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var body = try #require(envelope["body"] as? [String: Any])
    change(&body)
    let payload = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
    envelope["body"] = body
    envelope["sha256"] = RecordingChunkCodec.digest(Data("PSLOwnerAuthorityCommand2\n".utf8) + payload)
    return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys, .withoutEscapingSlashes])
}
