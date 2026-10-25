import Foundation
import Testing
@testable import PadelCore

@Suite struct VideoMotionBridgeProtocolTests {
    private let phoneDomain = UUID(uuidString: "B1000000-0000-0000-0000-000000000001")!
    private let watchDomain = UUID(uuidString: "B1000000-0000-0000-0000-000000000002")!

    private func bridge(_ device: VideoMotionDevice, uncertainty: Double = 0.000_000_001,
                        domain: UUID? = nil, epoch: UUID? = nil, runtime: Double = 0) throws -> VideoMotionClockBridge {
        let source: Double = device == .phone ? 100 : 200
        return try VideoMotionClockBridge(device: device,
            sourceClockDomainID: domain ?? (device == .phone ? phoneDomain : watchDomain),
            runtimeEpoch: epoch ?? (device == .phone ? videoTestPhoneRun : videoTestWatchRun),
            source: device == .phone ? .coreMediaHost : .machAbsolute(ticks: 200_000_000_000, numerator: 1, denominator: 1),
            sourceBeforeSeconds: source, sourceAfterSeconds: source,
            runtimeBeforeSeconds: runtime, runtimeAfterSeconds: runtime, roundingUncertaintySeconds: uncertainty)
    }
    private func phone(_ bridge: VideoMotionClockBridge?, timestamp: Double = 106) throws -> VideoMotionPhoneStart {
        try VideoMotionPhoneStart(writerGeneration: UUID(), clockDomainID: phoneDomain,
            firstVideoPTS: .init(value: 6_000, timescale: 1_000, epoch: 0),
            firstAudioPTS: .init(value: 5_990, timescale: 1_000, epoch: 0), firstHostTime: timestamp, clockBridge: bridge)
    }
    private func motion(_ bridge: VideoMotionClockBridge?, last: Double = 208.3) throws -> VideoMotionMotionReady {
        try VideoMotionMotionReady(captureGeneration: UUID(), clockDomainID: watchDomain,
            firstTimestamp: 206.3, lastTimestamp: last, accelerationChunks: 1, deviceMotionChunks: 1,
            completedChunkCount: 2, manifestDigest: String(repeating: "a", count: 64), clockBridge: bridge)
    }
    private func envelope(_ message: VideoMotionControlMessage, binding: VideoMotionBinding,
                          sender: VideoMotionDevice, sequence: Int) throws -> VideoMotionControlEnvelope {
        try VideoMotionControlEnvelope(operationID: UUID(), binding: binding, armGeneration: videoTestArm,
            phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun, sender: sender, sequence: sequence, message: message)
    }
    private func trace(_ phone: VideoMotionPhoneStart, _ motion: VideoMotionMotionReady) throws
        -> (VideoMotionProtocol, VideoMotionControlEnvelope, [VideoMotionControlResult], VideoMotionEvidence) {
        let binding = try videoTestBinding()
        var state = try VideoMotionProtocol(binding: binding, armGeneration: videoTestArm,
            phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun, device: .watch)
        let scope = try VideoMotionTransportScope(binding: binding, armGeneration: videoTestArm,
            phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun)
        var evidence = try VideoMotionEvidence(scope: scope), results: [VideoMotionControlResult] = []
        let mapping = try videoTestClockMapping()
        for exchange in mapping.exchanges { evidence = try evidence.appending(.clockExchange(exchange)) }
        evidence = try evidence.appending(.clockMapping(mapping))
        let messages = [
            try envelope(.start, binding: binding, sender: .watch, sequence: 1),
            try envelope(.phoneStarted(phone), binding: binding, sender: .phone, sequence: 1),
            try envelope(.motionReady(motion), binding: binding, sender: .watch, sequence: 2),
            try envelope(.clockMapping(mapping), binding: binding, sender: .phone, sequence: 2)]
        for (command, time) in zip(messages, [0.0, 7, 9, 11]) {
            let result = try state.receive(command, at: time); results.append(result)
            evidence = try evidence.appending(.control(command, result.receipt, observer: .watch))
        }
        return (state, messages[3], results, evidence)
    }
    private func countdown(_ evidence: VideoMotionEvidence) throws -> VideoMotionEvidence {
        try evidence.appending(.transition(VideoMotionLocalTransition(device: .watch,
            phase: .capturing, kind: .countdown, timestamp: 11.01)))
    }

    @Test func nonzeroNativeBridgesEnableOneCountdownWithoutRewritingSourceTimestamps() throws {
        let phone = try phone(bridge(.phone)), motion = try motion(bridge(.watch))
        var (state, last, results, evidence) = try trace(phone, motion)
        #expect(state.canCountdown && results.flatMap(\.effects).filter { $0 == .beginCountdown }.count == 1)
        #expect(state.phoneStart?.firstHostTime == 106 && state.motionReady?.firstTimestamp == 206.3)
        #expect(state.motionReady?.lastTimestamp == 208.3)
        #expect(state.phoneStart?.clockBridge == phone.clockBridge && state.motionReady?.clockBridge == motion.clockBridge)
        #expect(try VideoMotionControlEnvelope.decode(last.encoded()) == last)
        let duplicate = try state.receive(last, at: 11.02)
        #expect(duplicate.effects.isEmpty && duplicate.receipt == results[3].receipt)
        let started = try countdown(evidence)
        #expect(started.phase(for: .watch) == .capturing)
        #expect(try VideoMotionEvidence.decode(started.encoded()) == started)
        let loss = try state.tick(at: 20)
        #expect(!state.canCountdown && state.peerStatus == .unknown && !loss.contains(.stopLocalCapture))
        #expect(try state.tick(at: 127).contains(.stopLocalCapture))
        #expect(state.phase == .stopping)
    }

    @Test func missingEitherNativeBridgeCannotStartCountdownEvenWhenRawTimesFitMapping() throws {
        let legacyPhone = try phone(nil, timestamp: 6)
        let legacyMotion = try VideoMotionMotionReady(captureGeneration: UUID(), clockDomainID: watchDomain,
            firstTimestamp: 6.3, lastTimestamp: 8.3, accelerationChunks: 1, deviceMotionChunks: 1,
            completedChunkCount: 2, manifestDigest: String(repeating: "a", count: 64))
        let combinations = [(legacyPhone, legacyMotion), (legacyPhone, try motion(bridge(.watch))),
                            (try phone(bridge(.phone)), legacyMotion)]
        for (phone, motion) in combinations {
            let (state, _, results, evidence) = try trace(phone, motion)
            #expect(!state.canCountdown && !results.flatMap(\.effects).contains(.beginCountdown))
            #expect(throws: (any Error).self) { try countdown(evidence) }
        }
    }

    @Test func nativeFactBridgeMustMatchSourceDeviceDomainAndScopeRuntimeEpoch() throws {
        #expect(throws: (any Error).self) { try phone(bridge(.phone, domain: UUID())) }
        #expect(throws: (any Error).self) { try motion(bridge(.watch, domain: UUID())) }
        #expect(throws: (any Error).self) { try phone(bridge(.watch, domain: phoneDomain)) }
        #expect(throws: (any Error).self) { try motion(bridge(.phone, domain: watchDomain)) }
        let binding = try videoTestBinding()
        let wrongPhone = try phone(bridge(.phone, epoch: UUID()))
        let wrongWatch = try motion(bridge(.watch, epoch: UUID()))
        #expect(throws: (any Error).self) {
            try envelope(.phoneStarted(wrongPhone), binding: binding, sender: .phone, sequence: 1)
        }
        #expect(throws: (any Error).self) {
            try envelope(.motionReady(wrongWatch), binding: binding, sender: .watch, sequence: 2)
        }
    }

    @Test func coverageRejectsAnyUnsupportedIntervalEndpointEvenWithSupportedMidpoint() throws {
        let mapping = try videoTestClockMapping()
        #expect((try? mapping.estimateWatch(atPhone: 10.025)) != nil)
        #expect((try? mapping.estimatePhone(atWatch: 10.21)) != nil)
        let inputs = [
            (try phone(bridge(.phone, uncertainty: 0.01), timestamp: 110.025), try motion(bridge(.watch))),
            (try phone(bridge(.phone)), try motion(bridge(.watch, uncertainty: 0.02), last: 210.21))]
        for (phone, motion) in inputs {
            let (state, _, results, evidence) = try trace(phone, motion)
            #expect(!state.canCountdown && !results.flatMap(\.effects).contains(.beginCountdown))
            #expect(throws: (any Error).self) { try countdown(evidence) }
        }
    }

    @Test func retainedAndInControlBridgesMustAgreeAndBothConstrainCoverage() throws {
        let (state, _, _, evidence) = try trace(phone(bridge(.phone)), motion(bridge(.watch)))
        #expect(state.canCountdown)
        #expect(throws: (any Error).self) { try evidence.appending(.clockBridge(bridge(.phone, runtime: 1))) }
        let (wide, _, _, partial) = try trace(phone(bridge(.phone, uncertainty: 0.02), timestamp: 110.025), motion(bridge(.watch)))
        #expect(!wide.canCountdown)
        let narrowed = try partial.appending(.clockBridge(bridge(.phone)))
        #expect(try countdown(narrowed).phase(for: .watch) == .capturing)
        let before = try VideoMotionEvidence(scope: evidence.scope).appending(.clockBridge(bridge(.phone, runtime: 1)))
        let command = try envelope(.phoneStarted(phone(bridge(.phone))), binding: evidence.scope.binding, sender: .phone, sequence: 1)
        let receipt = VideoMotionControlReceipt(operationID: command.operationID,
            messageDigest: RecordingChunkCodec.digest(try command.encoded()), phase: .starting, acceptedAt: 1)
        #expect(throws: (any Error).self) { try before.appending(.control(command, receipt, observer: .phone)) }
    }
}


extension VideoMotionBridgeProtocolTests {
    @Test func offsetIntervalEnclosesOwnObservedRuntimeDespiteLargeSourceCancellation() throws {
        let source = 1_000_000_000_000.0, before = 0.1, after = 0.100_000_000_1
        let bridge = try VideoMotionClockBridge(device: .phone, sourceClockDomainID: UUID(), runtimeEpoch: videoTestPhoneRun,
            source: .coreMediaHost, sourceBeforeSeconds: source, sourceAfterSeconds: source,
            runtimeBeforeSeconds: before, runtimeAfterSeconds: after, roundingUncertaintySeconds: 0.000_000_001)
        let lower = (source + bridge.offsetRange.lowerBound).nextDown
        let upper = (source + bridge.offsetRange.upperBound).nextUp
        #expect(lower <= before && upper >= after)
        #expect(bridge.offsetRange.lowerBound < bridge.offsetRange.upperBound)
    }

    @Test func oldNativeControlCanonicalBytesRemainExactWithAbsentBridge() throws {
        // Frozen public-API controls from isolated archive ce9fde847bf158e0df3af219edf442c0780b0d77.
        let phoneBytes = Data(#"{"body":{"armGeneration":"90000000-0000-0000-0000-000000000003","binding":{"appBuild":"synthetic-8","createdAtUnixSeconds":1800000000,"preparation":{"authority":"eyJib2R5Ijp7ImF0dGVzdHNXYXRjaEFjY291bnRPd25lciI6dHJ1ZSwiY29sbGVjdGlvbkFsbG93ZWQiOnRydWUsImNvbnNlbnRHZW5lcmF0aW9uIjoxLCJoZWFydFJhdGVDb25zZW50Ijp0cnVlLCJsYXN0RGVjaXNpb24iOnsiYWNrbm93bGVkZ2VzV2l0aGRyYXdhbCI6ZmFsc2UsImNvbmZpcm1lZEF0VW5peFNlY29uZHMiOjE4MDAwMDAwMDAsImV4cGVjdGVkQ29uc2VudEdlbmVyYXRpb24iOjAsImV4cGVjdGVkUmV2aXNpb24iOjAsImlkIjoiNDQ0NDQ0NDQtNDQ0NC00NDQ0LTQ0NDQtNDQ0NDQ0NDQ0NDQ0IiwiaW5jbHVkZXNIZWFydFJhdGUiOnRydWUsImtpbmQiOiJlbnJvbGwiLCJvYnNlcnZlZFdpdGhkcmF3YWxCYXJyaWVyIjowLCJvd25lcklEIjoiMTExMTExMTEtMTExMS0xMTExLTExMTEtMTExMTExMTExMTExIiwicGhvbmVFcG9jaCI6IjIyMjIyMjIyLTIyMjItMjIyMi0yMjIyLTIyMjIyMjIyMjIyMiIsInBvbGljeURpZ2VzdCI6IjdiYjhjNjVlMTQwNzhmYTJjYjE2MjE0NDkwMDU0NDhhYmQxZTQ1MDg0OGVhZGVkYWYzYTY2NDdlODk3NzY5ZGQiLCJ3YXRjaEVwb2NoIjoiMzMzMzMzMzMtMzMzMy0zMzMzLTMzMzMtMzMzMzMzMzMzMzMzIn0sIm93bmVySUQiOiIxMTExMTExMS0xMTExLTExMTEtMTExMS0xMTExMTExMTExMTEiLCJwaG9uZUVwb2NoIjoiMjIyMjIyMjItMjIyMi0yMjIyLTIyMjItMjIyMjIyMjIyMjIyIiwicG9saWN5RGlnZXN0IjoiN2JiOGM2NWUxNDA3OGZhMmNiMTYyMTQ0OTAwNTQ0OGFiZDFlNDUwODQ4ZWFkZWRhZjNhNjY0N2U4OTc3NjlkZCIsInBvbGljeVZlcnNpb24iOjEsInJldmlzaW9uIjoxLCJzY2hlbWFWZXJzaW9uIjoxLCJzdHVkeUlEIjoiUFNMLU9XTkVSLUZILUJILTEiLCJ1c2VkRGVjaXNpb25JRHMiOlsiNDQ0NDQ0NDQtNDQ0NC00NDQ0LTQ0NDQtNDQ0NDQ0NDQ0NDQ0Il0sIndhdGNoRXBvY2giOiIzMzMzMzMzMy0zMzMzLTMzMzMtMzMzMy0zMzMzMzMzMzMzMzMiLCJ3aXRoZHJhd2FsQmFycmllciI6MH0sInNoYTI1NiI6IjY2NDFlYjYwNmNlNTkyN2RmZDlmY2M1OTkwMzA3YjY3YjBiYzQ2M2E2YjdiYTc3MWRlM2NlYWEwNmU4MjAwYWQifQ==","draft":{"canonicalDigest":"39790c825277d2838d85a53700050b5886d307b532d3c9931f238a550b9f0de9","captureMode":"videoMotionMixedReferenceV1","currentRacketArm":"right","intendedDrill":"otherUnclassified","originInstallationEpoch":"22222222-2222-2222-2222-222222222222","preparationID":"88888888-8888-8888-8888-888888888888","revision":1,"usualHand":"right"},"practiceID":"55555555-5555-5555-5555-555555555555"},"recordingID":"A0000000-0000-0000-0000-000000000002","schemaVersion":1,"sessionID":"A0000000-0000-0000-0000-000000000001"},"message":{"phoneStarted":{"_0":{"clockDomainID":"B0000000-0000-0000-0000-000000000002","firstAudioPTS":{"epoch":0,"timescale":1000,"value":5990},"firstHostTime":6,"firstVideoPTS":{"epoch":0,"timescale":1000,"value":6000},"writerGeneration":"B0000000-0000-0000-0000-000000000001"}}},"operationID":"B0000000-0000-0000-0000-000000000005","phoneEpoch":"90000000-0000-0000-0000-000000000001","schemaVersion":1,"sender":"phone","sequence":1,"watchEpoch":"90000000-0000-0000-0000-000000000002"},"sha256":"2a8f57ec66920aa172e5492145951c4ab214a0129e2cc9ee3dffe489f3b37f11"}"#.utf8)
        #expect(RecordingChunkCodec.digest(phoneBytes) == "aef417ad6e112bce47c382d83a5450043ac3c0eb8282d0ab46271825e38ffd04")
        let phone = try VideoMotionControlEnvelope.decode(phoneBytes)
        #expect(try phone.encoded() == phoneBytes)
        let watchBytes = Data(#"{"body":{"armGeneration":"90000000-0000-0000-0000-000000000003","binding":{"appBuild":"synthetic-8","createdAtUnixSeconds":1800000000,"preparation":{"authority":"eyJib2R5Ijp7ImF0dGVzdHNXYXRjaEFjY291bnRPd25lciI6dHJ1ZSwiY29sbGVjdGlvbkFsbG93ZWQiOnRydWUsImNvbnNlbnRHZW5lcmF0aW9uIjoxLCJoZWFydFJhdGVDb25zZW50Ijp0cnVlLCJsYXN0RGVjaXNpb24iOnsiYWNrbm93bGVkZ2VzV2l0aGRyYXdhbCI6ZmFsc2UsImNvbmZpcm1lZEF0VW5peFNlY29uZHMiOjE4MDAwMDAwMDAsImV4cGVjdGVkQ29uc2VudEdlbmVyYXRpb24iOjAsImV4cGVjdGVkUmV2aXNpb24iOjAsImlkIjoiNDQ0NDQ0NDQtNDQ0NC00NDQ0LTQ0NDQtNDQ0NDQ0NDQ0NDQ0IiwiaW5jbHVkZXNIZWFydFJhdGUiOnRydWUsImtpbmQiOiJlbnJvbGwiLCJvYnNlcnZlZFdpdGhkcmF3YWxCYXJyaWVyIjowLCJvd25lcklEIjoiMTExMTExMTEtMTExMS0xMTExLTExMTEtMTExMTExMTExMTExIiwicGhvbmVFcG9jaCI6IjIyMjIyMjIyLTIyMjItMjIyMi0yMjIyLTIyMjIyMjIyMjIyMiIsInBvbGljeURpZ2VzdCI6IjdiYjhjNjVlMTQwNzhmYTJjYjE2MjE0NDkwMDU0NDhhYmQxZTQ1MDg0OGVhZGVkYWYzYTY2NDdlODk3NzY5ZGQiLCJ3YXRjaEVwb2NoIjoiMzMzMzMzMzMtMzMzMy0zMzMzLTMzMzMtMzMzMzMzMzMzMzMzIn0sIm93bmVySUQiOiIxMTExMTExMS0xMTExLTExMTEtMTExMS0xMTExMTExMTExMTEiLCJwaG9uZUVwb2NoIjoiMjIyMjIyMjItMjIyMi0yMjIyLTIyMjItMjIyMjIyMjIyMjIyIiwicG9saWN5RGlnZXN0IjoiN2JiOGM2NWUxNDA3OGZhMmNiMTYyMTQ0OTAwNTQ0OGFiZDFlNDUwODQ4ZWFkZWRhZjNhNjY0N2U4OTc3NjlkZCIsInBvbGljeVZlcnNpb24iOjEsInJldmlzaW9uIjoxLCJzY2hlbWFWZXJzaW9uIjoxLCJzdHVkeUlEIjoiUFNMLU9XTkVSLUZILUJILTEiLCJ1c2VkRGVjaXNpb25JRHMiOlsiNDQ0NDQ0NDQtNDQ0NC00NDQ0LTQ0NDQtNDQ0NDQ0NDQ0NDQ0Il0sIndhdGNoRXBvY2giOiIzMzMzMzMzMy0zMzMzLTMzMzMtMzMzMy0zMzMzMzMzMzMzMzMiLCJ3aXRoZHJhd2FsQmFycmllciI6MH0sInNoYTI1NiI6IjY2NDFlYjYwNmNlNTkyN2RmZDlmY2M1OTkwMzA3YjY3YjBiYzQ2M2E2YjdiYTc3MWRlM2NlYWEwNmU4MjAwYWQifQ==","draft":{"canonicalDigest":"39790c825277d2838d85a53700050b5886d307b532d3c9931f238a550b9f0de9","captureMode":"videoMotionMixedReferenceV1","currentRacketArm":"right","intendedDrill":"otherUnclassified","originInstallationEpoch":"22222222-2222-2222-2222-222222222222","preparationID":"88888888-8888-8888-8888-888888888888","revision":1,"usualHand":"right"},"practiceID":"55555555-5555-5555-5555-555555555555"},"recordingID":"A0000000-0000-0000-0000-000000000002","schemaVersion":1,"sessionID":"A0000000-0000-0000-0000-000000000001"},"message":{"motionReady":{"_0":{"accelerationChunks":1,"captureGeneration":"B0000000-0000-0000-0000-000000000003","clockDomainID":"B0000000-0000-0000-0000-000000000004","completedChunkCount":2,"deviceMotionChunks":1,"firstTimestamp":6.3,"lastTimestamp":8.3,"manifestDigest":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}},"operationID":"B0000000-0000-0000-0000-000000000006","phoneEpoch":"90000000-0000-0000-0000-000000000001","schemaVersion":1,"sender":"watch","sequence":1,"watchEpoch":"90000000-0000-0000-0000-000000000002"},"sha256":"0b9c4ab4898f11c77bc2ab82b1ebf5c97e21f0d3bee031e78fb989e076c4113d"}"#.utf8)
        #expect(RecordingChunkCodec.digest(watchBytes) == "305650d8355d69b56b12fc40748a13f0ac6507b3fe798ee3985656372aef8cf6")
        let watch = try VideoMotionControlEnvelope.decode(watchBytes)
        #expect(try watch.encoded() == watchBytes)
        guard case .phoneStarted(let phoneFact) = phone.message, case .motionReady(let motionFact) = watch.message else {
            Issue.record("Historical native fact missing"); return
        }
        #expect(phoneFact.clockBridge == nil && motionFact.clockBridge == nil)
        #expect(phoneFact.firstHostTime == 6 && motionFact.firstTimestamp == 6.3 && motionFact.lastTimestamp == 8.3)
    }
}
