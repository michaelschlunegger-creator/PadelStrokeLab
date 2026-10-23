import Foundation
import CryptoKit
import Testing
@testable import PadelCore

let ownerTestSubject = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let ownerTestPhone = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
let ownerTestWatch = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
let ownerTestDecision = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

func ownerTestIdentity(heartRate: Bool = true) throws -> OwnerPracticeIdentity {
    try OwnerPracticeIdentity.enrolled(ownerID: ownerTestSubject,
        phoneInstallationEpoch: ownerTestPhone, watchInstallationEpoch: ownerTestWatch,
        attestsWatchAccountOwner: true, acceptsMotionStudy: true, includesHeartRate: heartRate,
        decisionID: ownerTestDecision, confirmedAtUnixSeconds: 1_800_000_000,
        policyDigest: OwnerPracticePolicy.digest)
}

/// Adversarial fixtures deliberately recompute a valid checksum around changed semantics.
func ownerTestResealed(_ bytes: Data, domain: String,
                       mutate: (inout [String: Any]) -> Void) throws -> Data {
    var envelope = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var body = try #require(envelope["body"] as? [String: Any])
    mutate(&body)
    let payload = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
    let digest = SHA256.hash(data: Data((domain + "\n").utf8) + payload)
        .map { String(format: "%02x", $0) }.joined()
    envelope["body"] = body
    envelope["sha256"] = digest
    return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys, .withoutEscapingSlashes])
}

@Suite struct OwnerPracticeIdentityTests {
    @Test func independentLiteralCanonicalIdentityAndPolicyDigest() throws {
        // Independently calculated with Python hashlib/json from the specified fields, not this codec.
        let literal = #"{"body":{"attestsWatchAccountOwner":true,"collectionAllowed":true,"consentGeneration":1,"heartRateConsent":true,"lastDecision":{"acknowledgesWithdrawal":false,"confirmedAtUnixSeconds":1800000000,"expectedConsentGeneration":0,"expectedRevision":0,"id":"44444444-4444-4444-4444-444444444444","includesHeartRate":true,"kind":"enroll","observedWithdrawalBarrier":0,"ownerID":"11111111-1111-1111-1111-111111111111","phoneEpoch":"22222222-2222-2222-2222-222222222222","policyDigest":"7bb8c65e14078fa2cb1621449005448abd1e450848eadedaf3a6647e897769dd","watchEpoch":"33333333-3333-3333-3333-333333333333"},"ownerID":"11111111-1111-1111-1111-111111111111","phoneEpoch":"22222222-2222-2222-2222-222222222222","policyDigest":"7bb8c65e14078fa2cb1621449005448abd1e450848eadedaf3a6647e897769dd","policyVersion":1,"revision":1,"schemaVersion":1,"studyID":"PSL-OWNER-FH-BH-1","usedDecisionIDs":["44444444-4444-4444-4444-444444444444"],"watchEpoch":"33333333-3333-3333-3333-333333333333","withdrawalBarrier":0},"sha256":"6641eb606ce5927dfd9fcc5990307b67b0bc463a6b7ba771de3ceaa06e8200ad"}"#
        #expect(OwnerPracticePolicy.digest == "7bb8c65e14078fa2cb1621449005448abd1e450848eadedaf3a6647e897769dd")
        #expect(try ownerTestIdentity().encoded() == Data(literal.utf8))
        #expect(try OwnerPracticeIdentity.decode(Data(literal.utf8)) == ownerTestIdentity())
    }

    @Test func recomputedChecksumCannotAuthorizeMalformedState() throws {
        let bytes = try ownerTestIdentity().encoded()
        let changes: [(inout [String: Any]) -> Void] = [
            { $0["schemaVersion"] = 2 }, { $0["policyVersion"] = 2 },
            { $0["studyID"] = "unrelated-study" }, { $0["attestsWatchAccountOwner"] = false },
            { $0["collectionAllowed"] = false }, { $0["consentGeneration"] = 0 },
            { $0["withdrawalBarrier"] = 1 }, { $0["revision"] = 0 },
            { $0["revision"] = Int64(9_007_199_254_740_991) },
            { $0["revision"] = Int64(9_007_199_254_740_990) },
            { $0["revision"] = Int64(9_007_199_254_740_992) },
            { $0["watchEpoch"] = ownerTestPhone.uuidString },
            { $0["ownerID"] = UUID().uuidString }, { $0["usedDecisionIDs"] = [] },
            { $0["usedDecisionIDs"] = [ownerTestDecision.uuidString, ownerTestDecision.uuidString] },
            { $0["unknownGrant"] = true },
            { var d = $0["lastDecision"] as! [String: Any]; d["kind"] = "restoreOwner"; $0["lastDecision"] = d },
            { var d = $0["lastDecision"] as! [String: Any]; d["expectedRevision"] = 1; $0["lastDecision"] = d }
        ]
        for change in changes {
            let invalid = try ownerTestResealed(bytes, domain: "PSLOwnerIdentity1", mutate: change)
            #expect(throws: (any Error).self) { try OwnerPracticeIdentity.decode(invalid) }
        }
    }

    @Test func revisionOverflowAndDecisionCapacityNeverResetGuards() throws {
        let bytes = try ownerTestResealed(ownerTestIdentity().encoded(), domain: "PSLOwnerIdentity1") {
            $0["revision"] = Int64(9_007_199_254_740_989)
        }
        let maximum = try OwnerPracticeIdentity.decode(bytes)
        #expect(throws: (any Error).self) { try maximum.advancingRevision(expectedRevision: maximum.revision) }
        let maximumDisabled = try maximum.applying(OwnerConsentDecision.heartRate(for: maximum,
            allowed: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_001,
            policyDigest: OwnerPracticePolicy.digest))
        #expect(maximumDisabled.isCollectionAllowed && !maximumDisabled.heartRateConsent)
        let maximumWithdrawn = try maximumDisabled.applying(OwnerConsentDecision.withdraw(for: maximumDisabled,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_001))
        #expect(maximumWithdrawn.revision == OwnerPracticeIdentity.maximumRevision)
        #expect(!maximumWithdrawn.isCollectionAllowed)
        #expect(throws: (any Error).self) {
            try maximumWithdrawn.advancingRevision(expectedRevision: maximumWithdrawn.revision)
        }
        var state = try ownerTestIdentity()
        for index in 1..<(OwnerPracticeIdentity.maximumConsentDecisions - 2) {
            state = try state.applying(OwnerConsentDecision.heartRate(for: state, allowed: true,
                decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000 + Double(index),
                policyDigest: OwnerPracticePolicy.digest))
        }
        #expect(try state.encoded().count <= 16_384)
        #expect(try OwnerPracticeIdentity.decode(state.encoded()) == state)
        let before = state
        #expect(throws: (any Error).self) {
            try state.applying(OwnerConsentDecision.heartRate(for: state, allowed: true, decisionID: UUID(),
                confirmedAtUnixSeconds: 1_800_000_200, policyDigest: OwnerPracticePolicy.digest))
        }
        #expect(state == before)
        let disabled = try state.applying(OwnerConsentDecision.heartRate(for: state, allowed: false,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_200, policyDigest: OwnerPracticePolicy.digest))
        #expect(disabled.isCollectionAllowed && !disabled.heartRateConsent && disabled.consentGeneration == 127)
        let withdrawal = try OwnerConsentDecision.withdraw(for: disabled, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_200)
        let withdrawn = try disabled.applying(withdrawal)
        #expect(!withdrawn.isCollectionAllowed && withdrawn.consentGeneration == 128)
        #expect(try withdrawn.applying(withdrawal) == withdrawn)
        #expect(throws: (any Error).self) {
            try withdrawn.applying(OwnerConsentDecision.reconsent(for: withdrawn, includesHeartRate: false,
                acknowledgesWithdrawal: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_201,
                policyDigest: OwnerPracticePolicy.digest))
        }
    }

    @Test func invalidTimePolicyOrReusedDecisionCannotGrant() throws {
        let owner = try ownerTestIdentity()
        for date in [Double.nan, .infinity, -1] {
            #expect(throws: (any Error).self) {
                try OwnerConsentDecision.heartRate(for: owner, allowed: true, decisionID: UUID(),
                    confirmedAtUnixSeconds: date, policyDigest: OwnerPracticePolicy.digest)
            }
        }
        #expect(throws: (any Error).self) {
            try OwnerConsentDecision.heartRate(for: owner, allowed: true, decisionID: UUID(),
                confirmedAtUnixSeconds: 1_800_000_001, policyDigest: String(repeating: "0", count: 64))
        }
        #expect(throws: (any Error).self) {
            try OwnerConsentDecision.heartRate(for: owner, allowed: false, decisionID: ownerTestDecision,
                confirmedAtUnixSeconds: 1_800_000_001, policyDigest: OwnerPracticePolicy.digest)
        }
        let other = try OwnerPracticeIdentity.enrolled(ownerID: UUID(), phoneInstallationEpoch: ownerTestPhone,
            watchInstallationEpoch: ownerTestWatch, attestsWatchAccountOwner: true, acceptsMotionStudy: true,
            includesHeartRate: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_000,
            policyDigest: OwnerPracticePolicy.digest)
        let command = try OwnerConsentDecision.withdraw(for: owner, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_001)
        #expect(throws: (any Error).self) { try other.applying(command) }
    }

    @Test func clockRollbackCannotPreventHRDisableOrWithdrawal() throws {
        let original = try ownerTestIdentity()
        let disable = try OwnerConsentDecision.heartRate(for: original, allowed: false, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_799_999_990, policyDigest: OwnerPracticePolicy.digest)
        let disabled = try original.applying(disable)
        #expect(disabled.isCollectionAllowed && !disabled.heartRateConsent)
        let withdrawal = try OwnerConsentDecision.withdraw(for: disabled, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_799_999_980)
        let withdrawn = try disabled.applying(withdrawal)
        #expect(!withdrawn.isCollectionAllowed && withdrawn.withdrawalBarrier == 3)
        #expect(throws: (any Error).self) { try withdrawn.applying(disable) }
        let bytes = try withdrawn.encoded()
        let envelope = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let body = try #require(envelope["body"] as? [String: Any])
        let decision = try #require(body["lastDecision"] as? [String: Any])
        #expect(decision["confirmedAtUnixSeconds"] as? Double == 1_799_999_980)
        #expect(try OwnerPracticeIdentity.decode(bytes) == withdrawn)
    }
    @Test func enrollmentIsExactOwnerPolicyNotAnImplicitRole() throws {
        let owner = try ownerTestIdentity()
        #expect(owner.revision == 1 && owner.consentGeneration == 1)
        #expect(owner.withdrawalBarrier == 0 && owner.isCollectionAllowed)
        #expect(owner.permits(ownerID: ownerTestSubject, phoneEpoch: ownerTestPhone,
            watchEpoch: ownerTestWatch, requiresHeartRate: true))
        #expect(!owner.permits(ownerID: UUID(), phoneEpoch: ownerTestPhone,
            watchEpoch: ownerTestWatch, requiresHeartRate: false))
        #expect(!owner.permits(ownerID: ownerTestSubject, phoneEpoch: UUID(),
            watchEpoch: ownerTestWatch, requiresHeartRate: false))
        #expect(!owner.permits(ownerID: ownerTestSubject, phoneEpoch: ownerTestPhone,
            watchEpoch: UUID(), requiresHeartRate: false))
        #expect(try OwnerPracticeIdentity.decode(owner.encoded()) == owner)
    }

    @Test func missingAttestationOrConsentCannotEnroll() throws {
        for (attested, accepted) in [(false, true), (true, false), (false, false)] {
            #expect(throws: (any Error).self) {
                try OwnerPracticeIdentity.enrolled(ownerID: ownerTestSubject,
                    phoneInstallationEpoch: ownerTestPhone, watchInstallationEpoch: ownerTestWatch,
                    attestsWatchAccountOwner: attested, acceptsMotionStudy: accepted,
                    includesHeartRate: false, decisionID: ownerTestDecision,
                    confirmedAtUnixSeconds: 1, policyDigest: OwnerPracticePolicy.digest)
            }
        }
    }

    @Test func withdrawalAndReconsentAreRevisionAndBarrierBound() throws {
        let original = try ownerTestIdentity()
        let beforeWithdrawalGrant = try OwnerConsentDecision.heartRate(for: original, allowed: false,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_001,
            policyDigest: OwnerPracticePolicy.digest)
        let command = try OwnerConsentDecision.withdraw(for: original, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_002)
        let withdrawn = try original.applying(command)
        #expect(!withdrawn.isCollectionAllowed && !withdrawn.heartRateConsent)
        #expect(withdrawn.withdrawalBarrier == 2 && withdrawn.consentGeneration == 2)
        #expect(try withdrawn.applying(command) == withdrawn)
        #expect(throws: (any Error).self) { try withdrawn.applying(beforeWithdrawalGrant) }
        #expect(throws: (any Error).self) {
            try OwnerConsentDecision.heartRate(for: withdrawn, allowed: true,
                decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_003,
                policyDigest: OwnerPracticePolicy.digest)
        }
        #expect(throws: (any Error).self) {
            try OwnerConsentDecision.reconsent(for: withdrawn, includesHeartRate: false,
                acknowledgesWithdrawal: false, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_003,
                policyDigest: OwnerPracticePolicy.digest)
        }
        let renewed = try OwnerConsentDecision.reconsent(for: withdrawn, includesHeartRate: false,
            acknowledgesWithdrawal: true, decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_003,
            policyDigest: OwnerPracticePolicy.digest)
        let active = try withdrawn.applying(renewed)
        #expect(active.isCollectionAllowed && !active.heartRateConsent)
        #expect(active.withdrawalBarrier == 2 && active.consentGeneration == 3)
        #expect(throws: (any Error).self) { try active.applying(command) }
        #expect(try OwnerPracticeIdentity.decode(active.encoded()) == active)
    }

    @Test func revisionMutationInvalidatesPendingConsentWithoutChangingScope() throws {
        let original = try ownerTestIdentity()
        let pending = try OwnerConsentDecision.withdraw(for: original, decisionID: UUID(),
            confirmedAtUnixSeconds: 1_800_000_001)
        let advanced = try original.advancingRevision(expectedRevision: 1)
        #expect(advanced.revision == 2 && advanced.consentGeneration == 1)
        #expect(advanced.isCollectionAllowed && advanced.heartRateConsent)
        #expect(throws: (any Error).self) { try advanced.applying(pending) }
        #expect(throws: (any Error).self) { try advanced.advancingRevision(expectedRevision: 1) }
    }

    @Test func optionalHRCanBeDisabledWithoutGrantingOtherScopes() throws {
        let original = try ownerTestIdentity()
        let decision = try OwnerConsentDecision.heartRate(for: original, allowed: false,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_001,
            policyDigest: OwnerPracticePolicy.digest)
        let changed = try original.applying(decision)
        #expect(changed.isCollectionAllowed && !changed.heartRateConsent)
        #expect(try changed.applying(decision) == changed)
        #expect(!changed.permits(ownerID: ownerTestSubject, phoneEpoch: ownerTestPhone,
            watchEpoch: ownerTestWatch, requiresHeartRate: true))
        #expect(original.heartRateConsent)
    }

    @Test func canonicalBoundaryRejectsUnknownDuplicateAndNoncanonicalJSON() throws {
        let data = try ownerTestIdentity().encoded()
        let literal = String(decoding: data, as: UTF8.self)
        for invalid in [" " + literal, literal + "\n", literal.replacingOccurrences(of: "\"schemaVersion\":1",
            with: "\"schemaVersion\":1,\"schemaVersion\":1"),
            literal.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"guest\":false")] {
            #expect(throws: (any Error).self) { try OwnerPracticeIdentity.decode(Data(invalid.utf8)) }
        }
        #expect(throws: (any Error).self) { try OwnerPracticeIdentity.decode(Data()) }
        #expect(throws: (any Error).self) {
            try OwnerPracticeIdentity.decode(Data(repeating: 32, count: 16_385))
        }
    }
}
