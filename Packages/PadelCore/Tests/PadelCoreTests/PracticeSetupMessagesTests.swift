import Foundation
import Testing
@testable import PadelCore

let setupOrigin = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
let setupPreparation = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
let setupRuntime = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
let setupGeneration = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
let setupRequestID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
let setupGenerations = PracticeSetupGenerations(runtimeGeneration: setupRuntime, preparationGeneration: setupGeneration)

func setupDraft(revision: Int64 = 1, origin: UUID = setupOrigin, preparation: UUID = setupPreparation,
                arm: PlayingArm = .left, hand: PlayingArm = .right,
                drill: RecordingDrill = .forehandGroundstroke) throws -> PracticeSetupDraft {
    try PracticeSetupDraft(originInstallationEpoch: origin, preparationID: preparation, revision: revision,
        preferences: PracticeSetupPreferences(currentRacketArm: arm, usualHand: hand, intendedDrill: drill))
}

func setupSnapshot(generations: PracticeSetupGenerations = setupGenerations,
                   current: PracticeSetupIdentity? = nil) throws -> PracticeSetupSnapshot {
    try PracticeSetupSnapshot(generations: generations, observedAtUnixSeconds: 1_800_000_000,
        state: .idle, wrist: .left, crown: .right, capability: .supported,
        storage: .available, acceptedCurrent: current)
}

struct PracticeSetupMessagesTests {
    @Test func exactLiteralDraftAndIndependentDigest() throws {
        let draft = try setupDraft()
        #expect(draft.identity.canonicalDigest == "cde5f28f7437e3b6ebe699f6f2f7f7f2d7805acdbacac4c1544d6f79083f7a8f")
        let literal = #"{"draft":{"canonicalDigest":"cde5f28f7437e3b6ebe699f6f2f7f7f2d7805acdbacac4c1544d6f79083f7a8f","currentRacketArm":"left","intendedDrill":"forehandGroundstroke","originInstallationEpoch":"11111111-1111-1111-1111-111111111111","preparationID":"22222222-2222-2222-2222-222222222222","revision":1,"usualHand":"right"},"kind":"PSLPracticeSetup1.draft","version":1}"#
        #expect(try PracticeSetupCodec.encode(.draft(draft)) == Data(literal.utf8))
        #expect(try PracticeSetupCodec.decode(Data(literal.utf8)) == .draft(draft))
        let discovery = #"{"kind":"PSLPracticeSetup1.statusRequest","requestID":"55555555-5555-5555-5555-555555555555","version":1}"#
        #expect(try PracticeSetupCodec.encode(.statusRequest(requestID: setupRequestID)) == Data(discovery.utf8))
    }

    @Test(arguments: PlayingArm.allCases, RecordingDrill.allCases)
    func finiteExistingVocabularyRoundTrips(arm: PlayingArm, drill: RecordingDrill) throws {
        let draft = try setupDraft(arm: arm, drill: drill)
        #expect(try PracticeSetupCodec.decode(PracticeSetupCodec.encode(.draft(draft))) == .draft(draft))
        #expect(draft.preferences.intendedDrill == drill)
        #expect(try setupDraft(hand: .left).identity != setupDraft().identity)
    }

    @Test func allKindsRetainBothGenerationsAndSeparateAcceptedReferences() throws {
        let draft = try setupDraft(), next = try setupDraft(revision: 2)
        let correlation = PracticeSetupCorrelation(requestID: setupRequestID, generations: setupGenerations, identity: draft.identity)
        let snapshot = try PracticeSetupSnapshot(generations: setupGenerations, observedAtUnixSeconds: 100,
            state: .recording, wrist: .left, crown: .right, capability: .supported, storage: .available,
            acceptedCurrent: draft.identity, acceptedNext: next.identity)
        let retired = PracticeSetupGenerations(runtimeGeneration: setupRuntime, preparationGeneration: UUID())
        let messages: [PracticeSetupMessage] = [
            .draft(draft), .statusRequest(requestID: setupRequestID), .status(requestID: setupRequestID, snapshot: snapshot),
            .prepare(requestID: setupRequestID, generations: setupGenerations, draft: draft, allowsOriginReplacement: false),
            .receipt(correlation: PracticeSetupCorrelation(requestID: setupRequestID, generations: setupGenerations, identity: next.identity), disposition: .acceptedNext, snapshot: snapshot),
            .retire(correlation: correlation, reason: .endPractice),
            .receipt(correlation: correlation, disposition: .retired, snapshot: try setupSnapshot(generations: retired)),
            .error(correlation: correlation, code: .staleGenerations, currentGenerations: retired)
        ]
        for message in messages {
            let bytes = try PracticeSetupCodec.encode(message)
            #expect(try PracticeSetupCodec.decode(bytes) == message)
            #expect(bytes.count <= 8_192)
            let text = String(decoding: bytes, as: UTF8.self)
            #expect(!text.contains("remoteStart") && !text.contains("physicalConfirmation"))
        }
        #expect(snapshot.acceptedCurrent == draft.identity && snapshot.acceptedNext == next.identity)
    }

    @Test func replyCorrelatesExactRequestIdentityAndBothGenerations() throws {
        let draft = try setupDraft()
        let request = PracticeSetupMessage.prepare(requestID: setupRequestID, generations: setupGenerations,
            draft: draft, allowsOriginReplacement: false)
        let correlation = try #require(request.correlation)
        let receipt = PracticeSetupMessage.receipt(correlation: correlation, disposition: .acceptedCurrent,
            snapshot: try setupSnapshot(current: draft.identity))
        #expect(receipt.isReply(to: request))
        let alternatives = [
            PracticeSetupGenerations(runtimeGeneration: UUID(), preparationGeneration: setupGeneration),
            PracticeSetupGenerations(runtimeGeneration: setupRuntime, preparationGeneration: UUID())
        ]
        for generations in alternatives {
            #expect(!receipt.isReply(to: .prepare(requestID: setupRequestID, generations: generations,
                draft: draft, allowsOriginReplacement: false)))
        }
        #expect(!receipt.isReply(to: .prepare(requestID: UUID(), generations: setupGenerations,
            draft: draft, allowsOriginReplacement: false)))
        #expect(!receipt.isReply(to: .prepare(requestID: setupRequestID, generations: setupGenerations,
            draft: try setupDraft(revision: 2), allowsOriginReplacement: false)))
        let failure = PracticeSetupMessage.error(correlation: correlation, code: .cancelled, currentGenerations: setupGenerations)
        #expect(failure.isReply(to: request))
        #expect(!receipt.isReply(to: .retire(correlation: correlation, reason: .endPractice)))
    }

    @Test func validationRejectsUnknownVersionFieldsEnumsAndNoncanonicalInput() throws {
        let literal = String(decoding: try PracticeSetupCodec.encode(.draft(setupDraft())), as: UTF8.self)
        for changed in [
            literal.replacingOccurrences(of: "\"version\":1", with: "\"version\":2"),
            literal.replacingOccurrences(of: "PSLPracticeSetup1.draft", with: "PSLPracticeSetup1.start"),
            literal.replacingOccurrences(of: "forehandGroundstroke", with: "automaticQuality"),
            literal.replacingOccurrences(of: "\"currentRacketArm\":\"left\"", with: "\"currentRacketArm\":\"unknown\""),
            literal.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":0"),
            literal.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":1.0"),
            literal.replacingOccurrences(of: "\"revision\":1", with: "\"revision\":1,\"revision\":1"),
            literal.replacingOccurrences(of: "\"version\":1", with: "\"physicalConfirmation\":true,\"version\":1"),
            literal.replacingOccurrences(of: "cde5f28f", with: "00000000"), " " + literal
        ] { #expect(throws: (any Error).self) { try PracticeSetupCodec.decode(Data(changed.utf8)) } }
        #expect(throws: (any Error).self) { try PracticeSetupCodec.decode(Data(repeating: 0x20, count: 8_193)) }
        #expect(throws: (any Error).self) { try PracticeSetupCodec.decode(Data()) }
        #expect(throws: (any Error).self) { try setupDraft(revision: -1) }
        #expect(throws: (any Error).self) { try setupDraft(revision: 9_007_199_254_740_992) }
        #expect(try setupDraft(revision: 9_007_199_254_740_991).identity.revision == 9_007_199_254_740_991)
    }

    @Test func snapshotUnknownsAndReceiptTransitionsFailClosed() throws {
        let unavailable = try PracticeSetupSnapshot(generations: setupGenerations, observedAtUnixSeconds: 0, state: .unavailable)
        #expect(unavailable.wrist == .unknown && unavailable.crown == .unknown && unavailable.capability == .unknown)
        #expect(throws: (any Error).self) {
            try PracticeSetupSnapshot(generations: setupGenerations, observedAtUnixSeconds: .infinity, state: .idle)
        }
        #expect(throws: (any Error).self) {
            try PracticeSetupSnapshot(generations: setupGenerations, observedAtUnixSeconds: 0, state: .unavailable, wrist: .left)
        }
        let draft = try setupDraft()
        let correlation = PracticeSetupCorrelation(requestID: setupRequestID, generations: setupGenerations, identity: draft.identity)
        #expect(throws: (any Error).self) {
            try PracticeSetupCodec.encode(.receipt(correlation: correlation, disposition: .acceptedCurrent, snapshot: unavailable))
        }
        #expect(throws: (any Error).self) {
            try PracticeSetupCodec.encode(.receipt(correlation: correlation, disposition: .retired, snapshot: setupSnapshot()))
        }
        let wrongRuntime = PracticeSetupGenerations(runtimeGeneration: UUID(), preparationGeneration: UUID())
        #expect(throws: (any Error).self) {
            try PracticeSetupCodec.encode(.receipt(correlation: correlation, disposition: .retired,
                snapshot: setupSnapshot(generations: wrongRuntime)))
        }
    }
    @Test func exactErrorLiteralAndMissingGenerationRejection() throws {
        let correlation = PracticeSetupCorrelation(requestID: setupRequestID, generations: setupGenerations, identity: try setupDraft().identity)
        let message = PracticeSetupMessage.error(correlation: correlation, code: .busy, currentGenerations: setupGenerations)
        let literal = #"{"code":"busy","correlation":{"generations":{"preparationGeneration":"44444444-4444-4444-4444-444444444444","runtimeGeneration":"33333333-3333-3333-3333-333333333333"},"identity":{"canonicalDigest":"cde5f28f7437e3b6ebe699f6f2f7f7f2d7805acdbacac4c1544d6f79083f7a8f","originInstallationEpoch":"11111111-1111-1111-1111-111111111111","preparationID":"22222222-2222-2222-2222-222222222222","revision":1},"requestID":"55555555-5555-5555-5555-555555555555"},"currentGenerations":{"preparationGeneration":"44444444-4444-4444-4444-444444444444","runtimeGeneration":"33333333-3333-3333-3333-333333333333"},"kind":"PSLPracticeSetup1.error","version":1}"#
        #expect(try PracticeSetupCodec.encode(message) == Data(literal.utf8))
        for key in ["runtimeGeneration", "preparationGeneration"] {
            let fragment = key == "runtimeGeneration" ? #","runtimeGeneration":"33333333-3333-3333-3333-333333333333""# : #""preparationGeneration":"44444444-4444-4444-4444-444444444444","#
            let malformed = literal.replacingOccurrences(of: fragment, with: "")
            #expect(malformed != literal)
            #expect(throws: (any Error).self) { try PracticeSetupCodec.decode(Data(malformed.utf8)) }
        }
        let unknown = literal.replacingOccurrences(of: "busy", with: "startNow")
        #expect(throws: (any Error).self) { try PracticeSetupCodec.decode(Data(unknown.utf8)) }
    }

    @Test func malformedConstructedReceiptCannotMatchARequest() throws {
        let draft = try setupDraft()
        let request = PracticeSetupMessage.prepare(requestID: setupRequestID, generations: setupGenerations,
            draft: draft, allowsOriginReplacement: false)
        let correlation = try #require(request.correlation)
        let changed = PracticeSetupGenerations(runtimeGeneration: setupRuntime, preparationGeneration: UUID())
        let receipt = PracticeSetupMessage.receipt(correlation: correlation, disposition: .acceptedCurrent,
            snapshot: try setupSnapshot(generations: changed, current: draft.identity))
        #expect(!receipt.isReply(to: request))
    }

}
