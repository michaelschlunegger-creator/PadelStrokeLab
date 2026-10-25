import Foundation
import Testing
@testable import PadelCore

/// Contract first: mixed recording is an explicitly accepted mode, never a relabelled forehand set.
@Suite struct VideoMotionAdmissionTests {
    private func preferences(drill: RecordingDrill = .otherUnclassified,
                             mode: RecordingCaptureMode? = .videoMotionMixedReferenceV1) -> PracticeSetupPreferences {
        PracticeSetupPreferences(currentRacketArm: .right, usualHand: .right,
                                 intendedDrill: drill, captureMode: mode)
    }

    private func draft(preferences value: PracticeSetupPreferences? = nil,
                       revision: Int64 = 1) throws -> PracticeSetupDraft {
        try PracticeSetupDraft(originInstallationEpoch: ownerTestPhone,
            preparationID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!, revision: revision,
            preferences: value ?? preferences())
    }

    private func raw(drill: RecordingDrill = .otherUnclassified,
                     protocolVersion: String = RecordingCaptureMode.videoMotionMixedReferenceV1.protocolVersion) throws -> Data {
        try RecordingChunkCodec.encodeMetadata(RecordingMetadata(recordingID: recordingTestID,
            clock: RecordingClock(domainID: recordingTestClockID, monotonicAnchorSeconds: 10,
                wallAnchorUnixSeconds: 1_800_000_000), appBuild: "7", protocolVersion: protocolVersion,
            deviceModel: "synthetic-watch", operatingSystem: "watchOS 27", handedness: .right,
            playingArm: .right, watchWrist: .right, watchOrientation: "Crown left", playingArmConfirmed: true,
            drill: drill.rawValue, capabilityReport: "synthetic supported",
            streams: RecordingStream.allCases.map {
                try RecordingStreamConfiguration(stream: $0, supported: true,
                    requestedRateHz: nil, knownSensorLimit: nil)
            }))
    }

    private func preparation(_ draft: PracticeSetupDraft) throws -> OwnerPreparation {
        try OwnerPreparation(authority: ownerTestIdentity(), practiceID: ownerTestPractice, draft: draft)
    }

    private func bind(_ raw: Data, draft: PracticeSetupDraft) throws -> OwnerContextBinding {
        try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: draft, generations: ownerTestGenerations)
    }

    @Test func mixedModeRoundTripsThroughPreparationAndImmutableContext() throws {
        let draft = try draft(), raw = try raw(), preparation = try preparation(draft)
        #expect(draft.preferences.captureMode == .videoMotionMixedReferenceV1)
        #expect(draft.preferences.intendedDrill == .otherUnclassified)
        #expect(try JSONDecoder().decode(PracticeSetupDraft.self,
            from: PracticeSetupJSON.encode(draft)) == draft)
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(.draft(preparation))) == .draft(preparation))
        let binding = try bind(raw, draft: draft)
        #expect(binding.context.captureMode == .videoMotionMixedReferenceV1)
        #expect(binding.context.manualStroke == .otherUnclassified)
        #expect(binding.context.acceptedSetup == draft)
        #expect(binding.rawMetadataBytes == raw)
        #expect(try OwnerRecordingContext.decode(binding.context.encoded(), rawMetadataBytes: raw) == binding.context)
        try binding.validateCurrentAuthority(ownerTestIdentity())
    }

    @Test func mixedModeRequiresExactAcceptedReceiptAndFreshModeIdentity() throws {
        let legacy = try preparation(ownerTestDraft())
        let mixed = try preparation(draft())
        // Even with the same sender preparation UUID/revision, the mode changes its canonical identity.
        #expect(legacy.identity.setup.preparationID == mixed.identity.setup.preparationID)
        #expect(legacy.identity.setup.revision == mixed.identity.setup.revision)
        #expect(legacy.identity.setup.canonicalDigest != mixed.identity.setup.canonicalDigest)
        #expect(legacy.identity != mixed.identity)
        let requestID = UUID()
        let oldCorrelation = OwnerPreparationCorrelation(requestID: requestID,
            generations: ownerTestGenerations, preparation: legacy.identity)
        let newCorrelation = OwnerPreparationCorrelation(requestID: requestID,
            generations: ownerTestGenerations, preparation: mixed.identity)
        let oldObservation = try OwnerPreparationObservation(watchEpoch: ownerTestWatch,
            generations: ownerTestGenerations, observedAtUnixSeconds: 5, state: .awaitingConfirmation,
            authority: ownerTestIdentity(), acceptedCurrent: legacy.identity)
        let oldReceipt = OwnerPreparationMessage.receipt(correlation: oldCorrelation,
            disposition: .acceptedCurrent, observation: oldObservation)
        let request = OwnerPreparationMessage.prepare(correlation: newCorrelation, preparation: mixed)
        #expect(!oldReceipt.isReply(to: request))
        #expect(throws: (any Error).self) {
            try OwnerPreparationCodec.encode(.prepare(correlation: oldCorrelation, preparation: mixed))
        }
        #expect(throws: (any Error).self) {
            try OwnerPreparationCodec.encode(.receipt(correlation: newCorrelation,
                disposition: .acceptedCurrent, observation: oldObservation))
        }
        let accepted = try OwnerPreparationObservation(watchEpoch: ownerTestWatch,
            generations: ownerTestGenerations, observedAtUnixSeconds: 6, state: .awaitingConfirmation,
            authority: ownerTestIdentity(), acceptedCurrent: mixed.identity)
        let newReceipt = OwnerPreparationMessage.receipt(correlation: newCorrelation,
            disposition: .acceptedCurrent, observation: accepted)
        #expect(newReceipt.isReply(to: request))
        #expect(try OwnerPreparationCodec.decode(OwnerPreparationCodec.encode(newReceipt)) == newReceipt)
        let next = try preparation(draft(revision: 2))
        let nextCorrelation = OwnerPreparationCorrelation(requestID: requestID,
            generations: ownerTestGenerations, preparation: next.identity)
        #expect(!newReceipt.isReply(to: .prepare(correlation: nextCorrelation, preparation: next)))
        let restarted = PracticeSetupGenerations(runtimeGeneration: UUID(),
            preparationGeneration: ownerTestGenerations.preparationGeneration)
        let stale = OwnerPreparationCorrelation(requestID: requestID, generations: restarted,
            preparation: mixed.identity)
        #expect(!newReceipt.isReply(to: .prepare(correlation: stale, preparation: mixed)))
    }

    @Test func mixedIntentCannotEnterThroughLegacyPreparationOrProtocol() throws {
        let unclassifiedLegacy = try draft(preferences: preferences(mode: nil))
        #expect(throws: (any Error).self) { try preparation(unclassifiedLegacy) }
        #expect(throws: (any Error).self) { try bind(raw(), draft: unclassifiedLegacy) }
        #expect(throws: (any Error).self) { try bind(raw(), draft: ownerTestDraft()) }
        #expect(throws: (any Error).self) {
            try bind(raw(protocolVersion: RecordingDrill.protocolVersion), draft: draft())
        }
        #expect(throws: (any Error).self) { try bind(ownerTestRaw(), draft: draft()) }
        // Adding a mixed protocol to otherwise ordinary forehand metadata grants no admission.
        #expect(throws: (any Error).self) {
            try bind(raw(drill: .forehandGroundstroke), draft: ownerTestDraft())
        }
    }

    @Test(arguments: RecordingDrill.allCases.filter { $0 != .otherUnclassified })
    func combinedModeNeverClaimsAWholeSetStroke(drill: RecordingDrill) throws {
        let invalid = try draft(preferences: preferences(drill: drill))
        #expect(throws: (any Error).self) { try preparation(invalid) }
        #expect(throws: (any Error).self) { try bind(raw(drill: drill), draft: invalid) }
    }

    @Test(arguments: RecordingDrill.allCases.filter {
        $0 != .forehandGroundstroke && $0 != .backhandGroundstroke
    })
    func normalOwnerModeKeepsItsExistingWhitelist(drill: RecordingDrill) throws {
        let invalid = try draft(preferences: preferences(drill: drill, mode: nil))
        #expect(throws: (any Error).self) { try preparation(invalid) }
        #expect(throws: (any Error).self) {
            try bind(raw(drill: drill, protocolVersion: RecordingDrill.protocolVersion), draft: invalid)
        }
    }

    @Test func unknownModeVersionAndDigestSubstitutionFailClosed() throws {
        let mixed = try draft()
        var object = try #require(JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(mixed)) as? [String: Any])
        object["captureMode"] = "videoMotionMixedReferenceV99"
        let unknown = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PracticeSetupDraft.self, from: unknown) }
        object.removeValue(forKey: "captureMode")
        let removed = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PracticeSetupDraft.self, from: removed) }
        var legacy = try #require(JSONSerialization.jsonObject(with: PracticeSetupJSON.encode(ownerTestDraft())) as? [String: Any])
        legacy["captureMode"] = RecordingCaptureMode.videoMotionMixedReferenceV1.rawValue
        let substituted = try JSONSerialization.data(withJSONObject: legacy, options: [.sortedKeys])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PracticeSetupDraft.self, from: substituted) }
    }

    @Test func resealedContextCannotInventOrRemoveMixedMode() throws {
        let raw = try raw(), binding = try bind(raw, draft: draft())
        let changes: [(inout [String: Any]) -> Void] = [
            { $0["schemaVersion"] = 99 },
            { $0["schemaVersion"] = 1 },
            { $0["captureMode"] = "videoMotionMixedReferenceV99" },
            { $0.removeValue(forKey: "captureMode") }
        ]
        for change in changes {
            let bytes = try ownerTestResealed(binding.context.encoded(), domain: "PSLOwnerContext1", mutate: change)
            #expect(throws: (any Error).self) { try OwnerRecordingContext.decode(bytes, rawMetadataBytes: raw) }
        }
        let oldRaw = try ownerTestRaw(), old = try bind(oldRaw, draft: ownerTestDraft())
        let added = try ownerTestResealed(old.context.encoded(), domain: "PSLOwnerContext1") {
            $0["captureMode"] = RecordingCaptureMode.videoMotionMixedReferenceV1.rawValue
        }
        #expect(throws: (any Error).self) { try OwnerRecordingContext.decode(added, rawMetadataBytes: oldRaw) }
    }

    @Test func mixedBindingStillRetiresOnAuthorityChange() throws {
        let binding = try bind(raw(), draft: draft()), owner = try ownerTestIdentity()
        let changed = try owner.advancingRevision(expectedRevision: owner.revision)
        #expect(throws: (any Error).self) { try binding.validateCurrentAuthority(changed) }
        let withdrawn = try owner.applying(OwnerConsentDecision.withdraw(for: owner,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_001))
        #expect(throws: (any Error).self) {
            try OwnerRecordingContext.bind(rawMetadataBytes: raw(), authority: withdrawn,
                practiceID: ownerTestPractice, acceptedSetup: draft(), generations: ownerTestGenerations)
        }
    }

    @Test func legacyDefaultBytesAndIndependentContextDigestRemainIdentical() throws {
        let implicit = PracticeSetupPreferences(currentRacketArm: .right, usualHand: .right,
            intendedDrill: .forehandGroundstroke)
        let explicit = preferences(drill: .forehandGroundstroke, mode: nil)
        let literal = Data("{\"currentRacketArm\":\"right\",\"intendedDrill\":\"forehandGroundstroke\",\"usualHand\":\"right\"}".utf8)
        #expect(implicit == explicit)
        #expect(try PracticeSetupJSON.encode(implicit) == literal)
        #expect(try PracticeSetupJSON.encode(explicit) == literal)
        #expect(try JSONDecoder().decode(PracticeSetupPreferences.self, from: literal) == implicit)
        let raw = try ownerTestRaw(), oldDraft = try ownerTestDraft()
        #expect(oldDraft.preferences.captureMode == nil)
        #expect(try draft(preferences: explicit) == oldDraft)
        let binding = try bind(raw, draft: oldDraft)
        #expect(binding.context.captureMode == nil)
        #expect(binding.context.rawMetadataDigest == "2e60fca454b0a62d0b4c072500b6603cf61c40e835103059aeb4c42e87fd44c3")
        #expect(try RecordingChunkCodec.digest(binding.context.encoded()) == "6799cc7d6b88236c635907eabbb934b6289fffc65b51e1c5f86bfd6b7f3d076d")
    }
}
