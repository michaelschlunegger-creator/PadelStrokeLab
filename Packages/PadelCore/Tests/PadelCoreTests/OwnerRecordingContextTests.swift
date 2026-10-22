import Foundation
import Testing
@testable import PadelCore

let ownerTestPractice = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
let ownerTestGenerations = PracticeSetupGenerations(
    runtimeGeneration: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
    preparationGeneration: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!)

func ownerTestDraft(drill: RecordingDrill = .forehandGroundstroke,
                    arm: PlayingArm = .right, origin: UUID = ownerTestPhone) throws -> PracticeSetupDraft {
    try PracticeSetupDraft(originInstallationEpoch: origin,
        preparationID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!, revision: 1,
        preferences: PracticeSetupPreferences(currentRacketArm: arm, usualHand: .right, intendedDrill: drill))
}

func ownerTestRaw(drill: String = "forehandGroundstroke", arm: PlayingArm = .right,
                  crown: String = "Crown left", bothStreams: Bool = true) throws -> Data {
    let metadata = try RecordingMetadata(recordingID: recordingTestID,
        clock: RecordingClock(domainID: recordingTestClockID, monotonicAnchorSeconds: 10,
            wallAnchorUnixSeconds: 1_800_000_000), appBuild: "7", protocolVersion: RecordingDrill.protocolVersion,
        deviceModel: "synthetic-watch", operatingSystem: "watchOS 27", handedness: .right,
        playingArm: arm, watchWrist: arm, watchOrientation: crown, playingArmConfirmed: true,
        drill: drill, capabilityReport: "synthetic supported",
        streams: (bothStreams ? RecordingStream.allCases : [.accelerometer]).map {
            try RecordingStreamConfiguration(stream: $0, supported: true, requestedRateHz: nil, knownSensorLimit: nil)
        })
    return try RecordingChunkCodec.encodeMetadata(metadata)
}

@Suite struct OwnerRecordingContextTests {
    @Test func independentCanonicalContextAndRawDigests() throws {
        // Python hashlib/json vectors explicitly specify each field independently of the Swift encoders.
        let raw = try ownerTestRaw()
        let binding = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        #expect(binding.context.rawMetadataDigest == "2e60fca454b0a62d0b4c072500b6603cf61c40e835103059aeb4c42e87fd44c3")
        #expect(binding.context.authorityDigest == "dae6241f88a4e959e6f16a7080fbaa67af6071191a982194300422b5f87de584")
        #expect(try RecordingChunkCodec.digest(binding.context.encoded()) == "6799cc7d6b88236c635907eabbb934b6289fffc65b51e1c5f86bfd6b7f3d076d")
    }

    @Test(arguments: PlayingArm.allCases, ["Crown left", "Crown right"])
    func bothArmsAndCrownDirectionsPreserveRawAxes(arm: PlayingArm, crown: String) throws {
        let raw = try ownerTestRaw(arm: arm, crown: crown)
        let bound = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(arm: arm), generations: ownerTestGenerations)
        #expect(bound.context.metadata.watchWrist == arm)
        #expect(bound.context.metadata.watchOrientation == crown)
        #expect(bound.rawMetadataBytes == raw)
    }

    @Test func recomputedContextChecksumCannotChangeBindingsOrPolicy() throws {
        let raw = try ownerTestRaw()
        let context = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations).context
        let changes: [(inout [String: Any]) -> Void] = [
            { $0["schemaVersion"] = 2 }, { $0["studyID"] = "guest-study" },
            { $0["acquisitionMode"] = "guestWorkout" }, { $0["recordingID"] = UUID().uuidString },
            { $0["clockDomainID"] = UUID().uuidString }, { $0["watchWrist"] = "left" },
            { $0["playingArm"] = "left" }, { $0["watchOrientation"] = "Crown right" },
            { $0["rawMetadataDigest"] = String(repeating: "0", count: 64) },
            { $0["authorityDigest"] = "bad" }, { $0["authorityRevision"] = 0 },
            { $0["authorityRevision"] = Int64(9_007_199_254_740_991) },
            { $0["authorityRevision"] = Int64(9_007_199_254_740_990) },
            { $0["authorityRevision"] = 127; $0["consentGeneration"] = 127 },
            { $0["authorityRevision"] = 128; $0["consentGeneration"] = 128; $0["heartRateConsent"] = false },
            { $0["consentGeneration"] = 2 }, { $0["withdrawalBarrier"] = 1 },
            { $0["policyDigest"] = String(repeating: "0", count: 64) },
            { $0["phoneEpoch"] = UUID().uuidString }, { $0["unknownOwnerRole"] = true }
        ]
        for change in changes {
            let invalid = try ownerTestResealed(context.encoded(), domain: "PSLOwnerContext1", mutate: change)
            #expect(throws: (any Error).self) { try OwnerRecordingContext.decode(invalid, rawMetadataBytes: raw) }
        }
    }

    @Test func changedPracticeAndEitherGenerationCreateDifferentContextIdentity() throws {
        let raw = try ownerTestRaw()
        let original = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        for generations in [
            PracticeSetupGenerations(runtimeGeneration: UUID(), preparationGeneration: ownerTestGenerations.preparationGeneration),
            PracticeSetupGenerations(runtimeGeneration: ownerTestGenerations.runtimeGeneration, preparationGeneration: UUID())
        ] {
            let other = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
                practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: generations)
            #expect(try other.context.encoded() != original.context.encoded())
        }
        let otherPractice = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: ownerTestIdentity(),
            practiceID: UUID(), acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        #expect(try otherPractice.context.encoded() != original.context.encoded())
        #expect(otherPractice.rawMetadataBytes == raw)
    }
    @Test(arguments: [RecordingDrill.forehandGroundstroke, .backhandGroundstroke])
    func exactContextForBothManualStrokes(drill: RecordingDrill) throws {
        let raw = try ownerTestRaw(drill: drill.rawValue)
        let authority = try ownerTestIdentity()
        let bound = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: authority,
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(drill: drill),
            generations: ownerTestGenerations)
        #expect(bound.context.recordingID == recordingTestID)
        #expect(bound.context.rawMetadataDigest == RecordingChunkCodec.digest(raw))
        #expect(bound.context.manualStroke == drill)
        #expect(bound.context.ownerID == ownerTestSubject)
        try bound.validateCurrentAuthority(authority)
        let bytes = try bound.context.encoded()
        #expect(try OwnerRecordingContext.decode(bytes, rawMetadataBytes: raw) == bound.context)
        #expect(try RecordingChunkCodec.encodeMetadata(bound.context.metadata) == raw)
    }

    @Test func wrongSetupOrLegacyRawCannotAcquireOwnerProvenance() throws {
        let owner = try ownerTestIdentity()
        let cases: [(Data, PracticeSetupDraft)] = [
            (try ownerTestRaw(), try ownerTestDraft(drill: .backhandGroundstroke)),
            (try ownerTestRaw(), try ownerTestDraft(arm: .left)),
            (try ownerTestRaw(), try ownerTestDraft(origin: UUID())),
            (try ownerTestRaw(drill: "forehandVolley"), try ownerTestDraft(drill: .forehandVolley)),
            (try ownerTestRaw(crown: "unknown"), try ownerTestDraft()),
            (try ownerTestRaw(bothStreams: false), try ownerTestDraft())
        ]
        for (raw, draft) in cases {
            #expect(throws: (any Error).self) {
                try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: owner,
                    practiceID: ownerTestPractice, acceptedSetup: draft, generations: ownerTestGenerations)
            }
        }
    }

    @Test func boundTokenDoesNotSurviveAuthorityMutation() throws {
        let owner = try ownerTestIdentity()
        let bound = try OwnerRecordingContext.bind(rawMetadataBytes: ownerTestRaw(), authority: owner,
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        let advanced = try owner.advancingRevision(expectedRevision: owner.revision)
        #expect(throws: (any Error).self) { try bound.validateCurrentAuthority(advanced) }
        let withdrawn = try owner.applying(OwnerConsentDecision.withdraw(for: owner,
            decisionID: UUID(), confirmedAtUnixSeconds: 1_800_000_001))
        #expect(throws: (any Error).self) {
            try OwnerRecordingContext.bind(rawMetadataBytes: ownerTestRaw(), authority: withdrawn,
                practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        }
        // Reading the immutable past context is allowed; it cannot create a publication binding.
        #expect(try OwnerRecordingContext.decode(bound.context.encoded(),
            rawMetadataBytes: ownerTestRaw()) == bound.context)
    }

    @Test func canonicalRawAndContextAreRequiredEvenWithValidSemanticMetadata() throws {
        let owner = try ownerTestIdentity()
        let raw = try ownerTestRaw()
        let bound = try OwnerRecordingContext.bind(rawMetadataBytes: raw, authority: owner,
            practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        #expect(throws: (any Error).self) {
            try OwnerRecordingContext.bind(rawMetadataBytes: Data([32]) + raw, authority: owner,
                practiceID: ownerTestPractice, acceptedSetup: ownerTestDraft(), generations: ownerTestGenerations)
        }
        #expect(throws: (any Error).self) {
            try OwnerRecordingContext.decode(bound.context.encoded(), rawMetadataBytes: ownerTestRaw(arm: .left))
        }
        #expect(throws: (any Error).self) {
            try OwnerRecordingContext.decode(Data([32]) + bound.context.encoded(), rawMetadataBytes: raw)
        }
        #expect(throws: (any Error).self) {
            try OwnerRecordingContext.decode(Data(repeating: 32, count: 8_193), rawMetadataBytes: raw)
        }
    }
}
