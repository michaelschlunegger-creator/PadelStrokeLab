import Foundation
import Testing
@testable import PadelCore

@Suite struct VideoMotionEvidenceTests {
    private func scope(_ binding: VideoMotionBinding) throws -> VideoMotionTransportScope {
        try .init(binding: binding, armGeneration: videoTestArm,
                  phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun)
    }
    private func control(_ scope: VideoMotionTransportScope, message: VideoMotionControlMessage = .start,
                         sequence: Int = 1) throws -> VideoMotionControlEnvelope {
        try .init(operationID: UUID(), binding: scope.binding, armGeneration: scope.armGeneration,
            phoneEpoch: scope.phoneEpoch, watchEpoch: scope.watchEpoch, sender: .watch, sequence: sequence, message: message)
    }
    private func receipt(_ control: VideoMotionControlEnvelope, phase: VideoMotionPhase = .starting) throws -> VideoMotionControlReceipt {
        VideoMotionControlReceipt(operationID: control.operationID,
            messageDigest: RecordingChunkCodec.digest(try control.encoded()), phase: phase, acceptedAt: 1)
    }

    @Test func nilEvidencePreservesHistoricalCanonicalBytesAndNewHistoryOnlyAppends() throws {
        let binding = try videoTestBinding(), original = try VideoMotionSession(binding: binding)
        let bytes = try original.encoded(), decoded = try VideoMotionSession.decode(bytes)
        let decodedBytes = try decoded.encoded()
        #expect(decoded.evidence == nil && decoded == original && decodedBytes == bytes)
        let envelope = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let body = try #require(envelope["body"] as? [String: Any]); #expect(body["evidence"] == nil)
        let empty = try VideoMotionEvidence(scope: scope(binding)), command = try control(empty.scope)
        let first = try empty.appending(.control(command, receipt(command), observer: .phone))
        let recorded = try original.next(evidence: first)
        let originalDigest = try original.digest
        #expect(recorded.binding == binding && recorded.previousDigest == originalDigest)
        #expect(try VideoMotionSession.decode(recorded.encoded()) == recorded)
        #expect(throws: (any Error).self) { try recorded.next(evidence: empty) }
        #expect(throws: (any Error).self) {
            try recorded.next(evidence: VideoMotionEvidence(scope: scope(videoTestBinding())))
        }
        #expect(try recorded.next().evidence == first)
    }

    @Test func exactDuplicateControlIsIdempotentConflictingReceiptAndForeignScopeFail() throws {
        let scope = try scope(videoTestBinding()), empty = try VideoMotionEvidence(scope: scope)
        let command = try control(scope), fact = try VideoMotionEvidenceFact.control(command, receipt(command), observer: .phone)
        let once = try empty.appending(fact)
        #expect(try once.appending(fact) == once && once.facts.count == 1)
        #expect(throws: (any Error).self) {
            try once.appending(.control(command, receipt(command, phase: .capturing), observer: .phone))
        }
        let other = try control(self.scope(videoTestBinding()))
        #expect(throws: (any Error).self) { try once.appending(.control(other, receipt(other), observer: .phone)) }
        let altered = VideoMotionControlReceipt(operationID: command.operationID,
            messageDigest: String(repeating: "a", count: 64), phase: .starting, acceptedAt: 1)
        #expect(throws: (any Error).self) { try empty.appending(.control(command, altered, observer: .phone)) }
        #expect(try VideoMotionEvidence.decode(once.encoded()) == once)
        let unknown = try ownerTestResealed(once.encoded(), domain: "PSLVideoMotionEvidence1") { $0["schemaVersion"] = 2 }
        #expect(throws: (any Error).self) { try VideoMotionEvidence.decode(unknown) }
    }

    @Test func observationsMustBeRetainedBeforeDerivedMappingAndEpochsMustMatch() throws {
        var evidence = try VideoMotionEvidence(scope: scope(videoTestBinding()))
        let mapping = try videoTestClockMapping()
        #expect(throws: (any Error).self) { try evidence.appending(.clockMapping(mapping)) }
        for exchange in mapping.exchanges { evidence = try evidence.appending(.clockExchange(exchange)) }
        evidence = try evidence.appending(.clockMapping(mapping))
        #expect(try evidence.appending(.clockMapping(mapping)) == evidence)
        #expect(throws: (any Error).self) {
            try evidence.appending(.clockExchange(videoTestClockExchange(at: 15, watchEpoch: UUID())))
        }
        #expect(try VideoMotionEvidence.decode(evidence.encoded()) == evidence)
    }

    @Test func nativeClockBridgeRetainsMeasuredBracketsAndMachTimebaseWithoutAssumingZeroOffset() throws {
        let source = UUID()
        let bridge = try VideoMotionClockBridge(device: .watch, sourceClockDomainID: source, runtimeEpoch: videoTestWatchRun,
            source: .machAbsolute(ticks: 100_000_000_000, numerator: 1, denominator: 1),
            sourceBeforeSeconds: 100, sourceAfterSeconds: 100,
            runtimeBeforeSeconds: 200.01, runtimeAfterSeconds: 200.03, roundingUncertaintySeconds: 0.000_000_001)
        #expect(bridge.offsetRange.contains(100.02) && !bridge.offsetRange.contains(0))
        #expect(bridge.offsetRange.lowerBound < 100.01 && bridge.offsetRange.upperBound > 100.03)
        var evidence = try VideoMotionEvidence(scope: scope(videoTestBinding()))
        evidence = try evidence.appending(.clockBridge(bridge))
        #expect(try VideoMotionEvidence.decode(evidence.encoded()) == evidence)
        #expect(throws: (any Error).self) {
            try VideoMotionClockBridge(device: .watch, sourceClockDomainID: source, runtimeEpoch: videoTestWatchRun,
                source: .machAbsolute(ticks: 100, numerator: 1, denominator: 0), sourceBeforeSeconds: 100,
                sourceAfterSeconds: 100, runtimeBeforeSeconds: 200, runtimeAfterSeconds: 201, roundingUncertaintySeconds: 0.001)
        }
        #expect(throws: (any Error).self) {
            try VideoMotionClockBridge(device: .phone, sourceClockDomainID: source, runtimeEpoch: videoTestPhoneRun,
                source: .coreMediaHost, sourceBeforeSeconds: 1, sourceAfterSeconds: 2,
                runtimeBeforeSeconds: 3, runtimeAfterSeconds: 4, roundingUncertaintySeconds: .nan)
        }
    }

    @Test func terminalDeviceCannotReviveAndLocalObservationsRemainMonotonic() throws {
        var evidence = try VideoMotionEvidence(scope: scope(videoTestBinding()))
        let command = try control(evidence.scope)
        evidence = try evidence.appending(.control(command, receipt(command), observer: .phone))
        let ended = try VideoMotionLocalTransition(device: .phone, phase: .terminal, kind: .stop, timestamp: 2)
        evidence = try evidence.appending(.transition(ended))
        #expect(evidence.phase(for: .phone) == .terminal)
        #expect(throws: (any Error).self) {
            try evidence.appending(.transition(VideoMotionLocalTransition(device: .phone, phase: .capturing, kind: .go, timestamp: 3)))
        }
        #expect(throws: (any Error).self) {
            try evidence.appending(.transition(VideoMotionLocalTransition(device: .phone, phase: .terminal, kind: .finalized, timestamp: 1)))
        }
        let delayed = try control(evidence.scope, sequence: 2)
        #expect(throws: (any Error).self) { try evidence.appending(.control(delayed, receipt(delayed), observer: .phone)) }
    }

    @Test func evidenceHistoryIsBoundedAndGoIsNotAFreeStandingClaim() throws {
        var evidence = try VideoMotionEvidence(scope: scope(videoTestBinding()))
        #expect(throws: (any Error).self) {
            try evidence.appending(.transition(VideoMotionLocalTransition(device: .phone, phase: .capturing, kind: .go, timestamp: 1)))
        }
        for index in 0..<VideoMotionEvidence.maximumFacts {
            evidence = try evidence.appending(.transition(VideoMotionLocalTransition(device: .phone, phase: .armed,
                kind: .phase, timestamp: Double(index))))
        }
        #expect(throws: (any Error).self) {
            try evidence.appending(.transition(VideoMotionLocalTransition(device: .phone, phase: .armed,
                kind: .phase, timestamp: Double(VideoMotionEvidence.maximumFacts))))
        }
        #expect(throws: (any Error).self) {
            try VideoMotionEvidence.decode(Data(repeating: 0, count: VideoMotionEvidence.maximumBytes + 1))
        }
    }
}


extension VideoMotionEvidenceTests {
    private func readyFacts(phoneSourceOffset: Double = 0, watchSourceOffset: Double = 0) throws
        -> (VideoMotionTransportScope, [VideoMotionEvidenceFact]) {
        let scope = try scope(videoTestBinding()), phoneSource = UUID(), watchSource = UUID()
        func observed(_ message: VideoMotionControlMessage, sender: VideoMotionDevice, sequence: Int,
                      phase: VideoMotionPhase, at time: Double) throws -> VideoMotionEvidenceFact {
            let command = try VideoMotionControlEnvelope(operationID: UUID(), binding: scope.binding,
                armGeneration: scope.armGeneration, phoneEpoch: scope.phoneEpoch, watchEpoch: scope.watchEpoch,
                sender: sender, sequence: sequence, message: message)
            let receipt = VideoMotionControlReceipt(operationID: command.operationID,
                messageDigest: RecordingChunkCodec.digest(try command.encoded()), phase: phase, acceptedAt: time)
            return .control(command, receipt, observer: .phone)
        }
        let phone = try VideoMotionPhoneStart(writerGeneration: UUID(), clockDomainID: phoneSource,
            firstVideoPTS: .init(value: 6_000, timescale: 1_000, epoch: 0),
            firstAudioPTS: .init(value: 5_990, timescale: 1_000, epoch: 0), firstHostTime: 6 + phoneSourceOffset)
        let motion = try VideoMotionMotionReady(captureGeneration: UUID(), clockDomainID: watchSource,
            firstTimestamp: 6.3 + watchSourceOffset, lastTimestamp: 8.3 + watchSourceOffset,
            accelerationChunks: 1, deviceMotionChunks: 1, completedChunkCount: 2,
            manifestDigest: String(repeating: "a", count: 64))
        let mapping = try videoTestClockMapping()
        var facts: [VideoMotionEvidenceFact] = [
            try observed(.start, sender: .watch, sequence: 1, phase: .starting, at: 1),
            try observed(.phoneStarted(phone), sender: .phone, sequence: 1, phase: .starting, at: 6),
            try observed(.motionReady(motion), sender: .watch, sequence: 2, phase: .capturing, at: 9)]
        facts += mapping.exchanges.map { .clockExchange($0) }; facts.append(.clockMapping(mapping))
        facts.append(.clockBridge(try VideoMotionClockBridge(device: .phone,
            sourceClockDomainID: phoneSource, runtimeEpoch: scope.phoneEpoch, source: .coreMediaHost,
            sourceBeforeSeconds: phoneSourceOffset, sourceAfterSeconds: phoneSourceOffset,
            runtimeBeforeSeconds: 0, runtimeAfterSeconds: 0, roundingUncertaintySeconds: 0.000_000_001)))
        facts.append(.clockBridge(try VideoMotionClockBridge(device: .watch,
            sourceClockDomainID: watchSource, runtimeEpoch: scope.watchEpoch,
            source: .machAbsolute(ticks: UInt64(watchSourceOffset * 1_000_000_000), numerator: 1, denominator: 1),
            sourceBeforeSeconds: watchSourceOffset, sourceAfterSeconds: watchSourceOffset,
            runtimeBeforeSeconds: 0, runtimeAfterSeconds: 0, roundingUncertaintySeconds: 0.000_000_001)))
        return (scope, facts)
    }

    private func retained(_ scope: VideoMotionTransportScope, _ facts: [VideoMotionEvidenceFact]) throws -> VideoMotionEvidence {
        try facts.reduce(VideoMotionEvidence(scope: scope)) { try $0.appending($1) }
    }

    @Test func supportedGoRequiresEveryNativeAndClockFactThenCannotRepeatOrRevive() throws {
        let (scope, facts) = try readyFacts()
        let countdown = try VideoMotionEvidenceFact.transition(VideoMotionLocalTransition(device: .phone,
            phase: .capturing, kind: .countdown, timestamp: 10.04))
        let go = try VideoMotionEvidenceFact.transition(VideoMotionLocalTransition(device: .phone,
            phase: .capturing, kind: .go, timestamp: 10.05))
        let ready = try retained(scope, facts)
        #expect(throws: (any Error).self) { try ready.appending(go) }
        let running = try ready.appending(countdown).appending(go)
        #expect(running.phase(for: .phone) == .capturing)
        #expect(try running.appending(go) == running)
        #expect(try VideoMotionEvidence.decode(running.encoded()) == running)
        let anotherGo = try VideoMotionEvidenceFact.transition(VideoMotionLocalTransition(device: .phone,
            phase: .capturing, kind: .go, timestamp: 10.06))
        #expect(throws: (any Error).self) { try running.appending(anotherGo) }
        let ended = try running.appending(.transition(VideoMotionLocalTransition(device: .phone,
            phase: .terminal, kind: .stop, timestamp: 11)))
        #expect(ended.phase(for: .phone) == .terminal)
        #expect(throws: (any Error).self) { try ended.appending(anotherGo) }
        let lateStart = try control(scope, sequence: 3)
        let lateReceipt = VideoMotionControlReceipt(operationID: lateStart.operationID,
            messageDigest: RecordingChunkCodec.digest(try lateStart.encoded()), phase: .starting, acceptedAt: 12)
        #expect(throws: (any Error).self) { try ended.appending(.control(lateStart, lateReceipt, observer: .phone)) }
        // Independently omit phone append, durable motion, mapping, phone bridge, and Watch bridge.
        for omitted in [1, 2, 6, 7, 8] {
            let incomplete = try retained(scope, facts.enumerated().filter { $0.offset != omitted }.map(\.element))
            #expect(throws: (any Error).self) { try incomplete.appending(countdown) }
        }
    }

    @Test func supportedGoConvertsMeasuredNonzeroSourceOffsetsBeforeMappingCoverage() throws {
        let (scope, facts) = try readyFacts(phoneSourceOffset: 100, watchSourceOffset: 200)
        let ready = try retained(scope, facts)
        let countdown = try ready.appending(.transition(VideoMotionLocalTransition(device: .phone,
            phase: .capturing, kind: .countdown, timestamp: 10.04)))
        let running = try countdown.appending(.transition(VideoMotionLocalTransition(device: .phone,
            phase: .capturing, kind: .go, timestamp: 10.05)))
        #expect(running.phase(for: .phone) == .capturing)
    }

    @Test func bridgeRejectsWrongRuntimeAndMachTicksOutsideStatedSourceBracket() throws {
        let scope = try scope(videoTestBinding()), empty = try VideoMotionEvidence(scope: scope)
        let forged = try VideoMotionClockBridge(device: .watch, sourceClockDomainID: UUID(), runtimeEpoch: UUID(),
            source: .machAbsolute(ticks: 100_000_000_000, numerator: 1, denominator: 1),
            sourceBeforeSeconds: 100, sourceAfterSeconds: 100,
            runtimeBeforeSeconds: 200, runtimeAfterSeconds: 200, roundingUncertaintySeconds: 0.000_000_001)
        #expect(throws: (any Error).self) { try empty.appending(.clockBridge(forged)) }
        #expect(throws: (any Error).self) {
            try VideoMotionClockBridge(device: .watch, sourceClockDomainID: UUID(), runtimeEpoch: scope.watchEpoch,
                source: .machAbsolute(ticks: 101_000_000_000, numerator: 1, denominator: 1),
                sourceBeforeSeconds: 100, sourceAfterSeconds: 100,
                runtimeBeforeSeconds: 200, runtimeAfterSeconds: 200, roundingUncertaintySeconds: 0.000_000_001)
        }
    }
}


extension VideoMotionEvidenceTests {
    @Test func nilEvidencePreservesFrozenPreEvidenceSessionBytes() throws {
        // Generated from public APIs in isolated source archive, before this field existed.
        // Source commit: ce9fde847bf158e0df3af219edf442c0780b0d77
        // Old VideoMotionSession.swift SHA256: 152819b7909f67e9569b99b407bd37cdd28ee8c1e99193ebcbc824be40bebd08.
        // Fixture SHA256: 967a0c24892713490b39c551e3c1a40dbd88f8d4a4259bff8c508ab1ff752775.
        let bytes = Data(#"{"body":{"annotations":[],"binding":{"appBuild":"synthetic-8","createdAtUnixSeconds":1800000000,"preparation":{"authority":"eyJib2R5Ijp7ImF0dGVzdHNXYXRjaEFjY291bnRPd25lciI6dHJ1ZSwiY29sbGVjdGlvbkFsbG93ZWQiOnRydWUsImNvbnNlbnRHZW5lcmF0aW9uIjoxLCJoZWFydFJhdGVDb25zZW50Ijp0cnVlLCJsYXN0RGVjaXNpb24iOnsiYWNrbm93bGVkZ2VzV2l0aGRyYXdhbCI6ZmFsc2UsImNvbmZpcm1lZEF0VW5peFNlY29uZHMiOjE4MDAwMDAwMDAsImV4cGVjdGVkQ29uc2VudEdlbmVyYXRpb24iOjAsImV4cGVjdGVkUmV2aXNpb24iOjAsImlkIjoiNDQ0NDQ0NDQtNDQ0NC00NDQ0LTQ0NDQtNDQ0NDQ0NDQ0NDQ0IiwiaW5jbHVkZXNIZWFydFJhdGUiOnRydWUsImtpbmQiOiJlbnJvbGwiLCJvYnNlcnZlZFdpdGhkcmF3YWxCYXJyaWVyIjowLCJvd25lcklEIjoiMTExMTExMTEtMTExMS0xMTExLTExMTEtMTExMTExMTExMTExIiwicGhvbmVFcG9jaCI6IjIyMjIyMjIyLTIyMjItMjIyMi0yMjIyLTIyMjIyMjIyMjIyMiIsInBvbGljeURpZ2VzdCI6IjdiYjhjNjVlMTQwNzhmYTJjYjE2MjE0NDkwMDU0NDhhYmQxZTQ1MDg0OGVhZGVkYWYzYTY2NDdlODk3NzY5ZGQiLCJ3YXRjaEVwb2NoIjoiMzMzMzMzMzMtMzMzMy0zMzMzLTMzMzMtMzMzMzMzMzMzMzMzIn0sIm93bmVySUQiOiIxMTExMTExMS0xMTExLTExMTEtMTExMS0xMTExMTExMTExMTEiLCJwaG9uZUVwb2NoIjoiMjIyMjIyMjItMjIyMi0yMjIyLTIyMjItMjIyMjIyMjIyMjIyIiwicG9saWN5RGlnZXN0IjoiN2JiOGM2NWUxNDA3OGZhMmNiMTYyMTQ0OTAwNTQ0OGFiZDFlNDUwODQ4ZWFkZWRhZjNhNjY0N2U4OTc3NjlkZCIsInBvbGljeVZlcnNpb24iOjEsInJldmlzaW9uIjoxLCJzY2hlbWFWZXJzaW9uIjoxLCJzdHVkeUlEIjoiUFNMLU9XTkVSLUZILUJILTEiLCJ1c2VkRGVjaXNpb25JRHMiOlsiNDQ0NDQ0NDQtNDQ0NC00NDQ0LTQ0NDQtNDQ0NDQ0NDQ0NDQ0Il0sIndhdGNoRXBvY2giOiIzMzMzMzMzMy0zMzMzLTMzMzMtMzMzMy0zMzMzMzMzMzMzMzMiLCJ3aXRoZHJhd2FsQmFycmllciI6MH0sInNoYTI1NiI6IjY2NDFlYjYwNmNlNTkyN2RmZDlmY2M1OTkwMzA3YjY3YjBiYzQ2M2E2YjdiYTc3MWRlM2NlYWEwNmU4MjAwYWQifQ==","draft":{"canonicalDigest":"39790c825277d2838d85a53700050b5886d307b532d3c9931f238a550b9f0de9","captureMode":"videoMotionMixedReferenceV1","currentRacketArm":"right","intendedDrill":"otherUnclassified","originInstallationEpoch":"22222222-2222-2222-2222-222222222222","preparationID":"88888888-8888-8888-8888-888888888888","revision":1,"usualHand":"right"},"practiceID":"55555555-5555-5555-5555-555555555555"},"recordingID":"A0000000-0000-0000-0000-000000000002","schemaVersion":1,"sessionID":"A0000000-0000-0000-0000-000000000001"},"retention":"reserved","revision":1,"schemaVersion":1},"sha256":"82605eb498a30f8f1bad44b445ea760c3f04cc76529fe1813544d0dbc4ca5dd1"}"#.utf8)
        #expect(RecordingChunkCodec.digest(bytes) == "967a0c24892713490b39c551e3c1a40dbd88f8d4a4259bff8c508ab1ff752775")
        let decoded = try VideoMotionSession.decode(bytes)
        #expect(decoded.evidence == nil && decoded.revision == 1)
        #expect(try decoded.encoded() == bytes)
        #expect(try VideoMotionSession(binding: decoded.binding).encoded() == bytes)
    }
}
