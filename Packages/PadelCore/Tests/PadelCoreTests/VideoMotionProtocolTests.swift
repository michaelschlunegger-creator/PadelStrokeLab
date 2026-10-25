import Foundation
import Testing
@testable import PadelCore

@Suite struct VideoMotionProtocolTests {
    private func envelope(_ message: VideoMotionControlMessage, binding: VideoMotionBinding,
                          sender: VideoMotionDevice = .watch, sequence: Int = 1,
                          operationID: UUID = UUID(), arm: UUID = videoTestArm,
                          phoneEpoch: UUID = videoTestPhoneRun) throws -> VideoMotionControlEnvelope {
        try VideoMotionControlEnvelope(operationID: operationID, binding: binding, armGeneration: arm,
            phoneEpoch: phoneEpoch, watchEpoch: videoTestWatchRun, sender: sender, sequence: sequence, message: message)
    }

    private func reducer(_ binding: VideoMotionBinding, device: VideoMotionDevice = .watch) throws -> VideoMotionProtocol {
        try VideoMotionProtocol(binding: binding, armGeneration: videoTestArm,
            phoneEpoch: videoTestPhoneRun, watchEpoch: videoTestWatchRun, device: device)
    }

    private func phoneFact() throws -> VideoMotionPhoneStart {
        try VideoMotionPhoneStart(writerGeneration: UUID(), clockDomainID: UUID(),
            firstVideoPTS: .init(value: 6_000, timescale: 1_000, epoch: 0),
            firstAudioPTS: .init(value: 5_990, timescale: 1_000, epoch: 0), firstHostTime: 6)
    }

    private func motionFact() throws -> VideoMotionMotionReady {
        try VideoMotionMotionReady(captureGeneration: UUID(), clockDomainID: recordingTestClockID,
            firstTimestamp: 6.3, lastTimestamp: 8.3, accelerationChunks: 1, deviceMotionChunks: 1,
            completedChunkCount: 2, manifestDigest: String(repeating: "a", count: 64))
    }

    @Test func exactEnvelopeRoundTripAndStrictVersionIdentityLimits() throws {
        let binding = try videoTestBinding(), message = try envelope(.start, binding: binding)
        let bytes = try message.encoded()
        #expect(try VideoMotionControlEnvelope.decode(bytes) == message)
        let unknown = try ownerTestResealed(bytes, domain: "PSLVideoMotionControl1") { $0["schemaVersion"] = 2 }
        #expect(throws: (any Error).self) { try VideoMotionControlEnvelope.decode(unknown) }
        #expect(throws: (any Error).self) { try VideoMotionControlEnvelope.decode(Data([32]) + bytes) }
        #expect(throws: (any Error).self) {
            try VideoMotionControlEnvelope.decode(Data(repeating: 0, count: VideoMotionControlEnvelope.maximumBytes + 1))
        }
        var state = try reducer(binding)
        for invalid in [try envelope(.start, binding: videoTestBinding()),
                        try envelope(.start, binding: binding, arm: UUID()),
                        try envelope(.start, binding: binding, phoneEpoch: UUID())] {
            #expect(throws: (any Error).self) { try state.receive(invalid, at: 0) }
        }
        #expect(state.phase == .armed)
    }

    @Test func duplicateOperationReturnsOriginalReceiptWithoutRepeatingEffects() throws {
        let binding = try videoTestBinding(), start = try envelope(.start, binding: binding)
        var state = try reducer(binding)
        let accepted = try state.receive(start, at: 0)
        #expect(accepted.effects == [.requestPhoneStart])
        let repeated = try state.receive(start, at: 1)
        #expect(repeated.receipt == accepted.receipt && repeated.effects.isEmpty)
        #expect(throws: (any Error).self) {
            try state.receive(envelope(.stop, binding: binding, operationID: start.operationID), at: 2)
        }
        #expect(throws: (any Error).self) {
            try state.receive(envelope(.heartbeat, binding: binding, sequence: 1), at: 2)
        }
    }

    @Test func countdownRequiresBothNativeFactsCompletedMotionAndUsableMapping() throws {
        let binding = try videoTestBinding()
        var state = try reducer(binding)
        _ = try state.receive(envelope(.start, binding: binding), at: 0)
        #expect(!state.canCountdown)
        let phone = try state.receive(envelope(.phoneStarted(phoneFact()), binding: binding,
            sender: .phone, sequence: 1), at: 7)
        #expect(phone.effects.contains(.beginLocalCapture))
        #expect(!state.canCountdown)
        _ = try state.receive(envelope(.motionReady(motionFact()), binding: binding, sequence: 2), at: 9)
        #expect(!state.canCountdown)
        let ready = try state.receive(envelope(.clockMapping(videoTestClockMapping()), binding: binding,
            sender: .phone, sequence: 2), at: 11)
        #expect(state.canCountdown)
        #expect(ready.effects.filter { $0 == .beginCountdown }.count == 1)
        let heartbeat = try state.receive(envelope(.heartbeat, binding: binding, sender: .phone, sequence: 3), at: 12)
        #expect(!heartbeat.effects.contains(.beginCountdown))
        #expect(throws: (any Error).self) {
            try VideoMotionMotionReady(captureGeneration: UUID(), clockDomainID: UUID(), firstTimestamp: 1,
                lastTimestamp: 2, accelerationChunks: 1, deviceMotionChunks: 0, completedChunkCount: 1,
                manifestDigest: String(repeating: "a", count: 64))
        }
        #expect(throws: (any Error).self) {
            try VideoMotionMotionReady(captureGeneration: UUID(), clockDomainID: UUID(), firstTimestamp: 1,
                lastTimestamp: 2, accelerationChunks: 1, deviceMotionChunks: 1, completedChunkCount: 1,
                manifestDigest: String(repeating: "a", count: 64))
        }
    }

    @Test func linkLossKeepsAlreadyRunningLocalCaptureAndDoesNotReplayStart() throws {
        let binding = try videoTestBinding(), start = try envelope(.start, binding: binding)
        var state = try reducer(binding, device: .phone)
        #expect(try state.receive(start, at: 0).effects == [.beginLocalCapture])
        _ = try state.receive(envelope(.phoneStarted(phoneFact()), binding: binding, sender: .phone), at: 7)
        let loss = try state.tick(at: 20)
        #expect(state.phase == .capturing && state.peerStatus == .unknown)
        #expect(!loss.contains(.stopLocalCapture) && !state.canCountdown)
        #expect(try state.receive(start, at: 21).effects.isEmpty)
        #expect(!state.canCountdown)
        #expect(try state.tick(at: 131).contains(.stopLocalCapture) == false)
        #expect(try state.tick(at: 132).contains(.stopLocalCapture))
        #expect(state.phase == .stopping)
    }

    @Test func stopIsImmediateLocalWhileMissingPeerReplyStaysUnknown() throws {
        let binding = try videoTestBinding()
        var state = try reducer(binding, device: .phone)
        _ = try state.receive(envelope(.start, binding: binding), at: 0)
        _ = try state.receive(envelope(.phoneStarted(phoneFact()), binding: binding, sender: .phone), at: 7)
        let stopped = try state.receive(envelope(.stop, binding: binding, sender: .phone, sequence: 2), at: 8)
        #expect(stopped.effects.contains(.stopLocalCapture) && stopped.effects.contains(.requestPeerStop))
        #expect(state.phase == .stopping)
        _ = try state.tick(at: 13)
        #expect(state.stopAcknowledgmentOverdue)
        let final = try VideoMotionFinalization(manifestDigest: String(repeating: "b", count: 64), interrupted: true)
        _ = try state.receive(envelope(.finalized(final), binding: binding, sender: .phone, sequence: 3), at: 14)
        #expect(state.phase == .terminal && state.stopAcknowledgmentOverdue)
        #expect(throws: (any Error).self) {
            try state.receive(envelope(.start, binding: binding, sequence: 2), at: 15)
        }
    }

    @Test func cancelBeforeCaptureAndStartupTimeoutFenceDelayedStarts() throws {
        let binding = try videoTestBinding()
        var cancelled = try reducer(binding)
        _ = try cancelled.receive(envelope(.cancel, binding: binding), at: 0)
        #expect(cancelled.phase == .terminal)
        #expect(throws: (any Error).self) {
            try cancelled.receive(envelope(.start, binding: binding, sequence: 2), at: 1)
        }
        var timedOut = try reducer(binding)
        _ = try timedOut.receive(envelope(.start, binding: binding), at: 0)
        _ = try timedOut.tick(at: 12)
        #expect(timedOut.phase == .terminal)
        let late = try timedOut.receive(envelope(.phoneStarted(phoneFact()), binding: binding, sender: .phone), at: 13)
        #expect(!late.effects.contains(.beginLocalCapture) && !timedOut.canCountdown)
        #expect(throws: (any Error).self) { try timedOut.tick(at: 11) }
    }
}
