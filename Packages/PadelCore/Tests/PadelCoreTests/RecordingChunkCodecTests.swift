import CryptoKit
import Foundation
import Testing
@testable import PadelCore

struct RecordingChunkCodecTests {
    @Test(arguments: RecordingStream.allCases)
    func roundTripPreservesEveryBit(_ stream: RecordingStream) throws {
        let sample = RecordingSample(timestamp: 123_456.123456789,
                                     values: (0..<stream.componentCount).map { $0 == 0 ? -0.0 : Double($0) / 7 })
        let chunk = try RecordingChunk(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
                                       stream: stream, sequence: 0, samples: [sample])
        let bytes = try RecordingChunkCodec.encode(chunk)
        #expect(bytes == (try RecordingChunkCodec.encode(chunk)))
        let decoded = try RecordingChunkCodec.decode(bytes)
        #expect(decoded.samples[0].timestamp.bitPattern == sample.timestamp.bitPattern)
        #expect(decoded.samples[0].values.map(\.bitPattern) == sample.values.map(\.bitPattern))
        #expect(decoded.recordingID == recordingTestID)
        #expect(decoded.clockDomainID == recordingTestClockID)
    }

    @Test(arguments: RecordingStream.allCases)
    func maximumWholeSamplePayload(_ stream: RecordingStream) throws {
        let samples = (0..<stream.maximumSamples).map {
            RecordingSample(timestamp: Double($0), values: Array(repeating: 1, count: stream.componentCount))
        }
        let chunk = try RecordingChunk(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
                                       stream: stream, sequence: 0, samples: samples)
        let bytes = try RecordingChunkCodec.encode(chunk)
        #expect(bytes.count <= 1_048_576)
        #expect(bytes.count + (stream.componentCount + 1) * 8 > 1_048_576)
        #expect(try RecordingChunkCodec.decode(bytes).samples.count == samples.count)
        #expect(throws: (any Error).self) {
            try RecordingChunk(recordingID: recordingTestID, clockDomainID: recordingTestClockID, stream: stream,
                               sequence: 0, samples: samples + [RecordingSample(timestamp: Double(samples.count), values: samples[0].values)])
        }
    }

    @Test func byteLimitsCheckedBeforeParsing() {
        #expect(throws: RecordingError.integrity("chunk header")) { try RecordingChunkCodec.decode(Data(count: 1_048_576)) }
        #expect(throws: RecordingError.limit("chunk bytes")) { try RecordingChunkCodec.decode(Data(count: 1_048_577)) }
        #expect(throws: RecordingError.limit("JSON bytes")) { try RecordingChunkCodec.decodeMetadata(Data(count: 16_385)) }
        #expect(throws: (any Error).self) { try RecordingChunkCodec.decodeMetadata(Data(count: 16_384)) }
    }

    @Test func invalidSamplesNeverSortOrCoerce() throws {
        for times in [[1, 1], [2, 1], [-1, 0], [Double.nan], [Double.infinity], []] {
            #expect(throws: (any Error).self) { try recordingChunk(times: times) }
        }
        for values in [[1, 2], [1, 2, Double.nan], [1, 2, Double.infinity]] {
            #expect(throws: (any Error).self) {
                try RecordingChunk(recordingID: recordingTestID, clockDomainID: recordingTestClockID,
                                   stream: .accelerometer, sequence: 0, samples: [.init(timestamp: 0, values: values)])
            }
        }
        #expect(throws: (any Error).self) { try recordingChunk(sequence: -1) }
        #expect(throws: (any Error).self) { try recordingChunk(sequence: 256) }
        _ = try recordingChunk(sequence: 255)
    }

    @Test func corruptedHeaderPayloadAndTrailerFail() throws {
        let data = try RecordingChunkCodec.encode(recordingChunk())
        for offset in [0, 8, 12, 16, 20, 24, 40, 56, 64, 72, data.count - 1] {
            var changed = data
            changed[offset] ^= 0x01
            #expect(throws: (any Error).self) { try RecordingChunkCodec.decode(changed) }
        }
        #expect(throws: (any Error).self) { try RecordingChunkCodec.decode(data.dropLast()) }
        #expect(throws: (any Error).self) { try RecordingChunkCodec.decode(data + Data([0])) }
    }

    @Test func internallyConsistentChecksumsCannotHideInvalidContent() throws {
        let data = try RecordingChunkCodec.encode(recordingChunk())
        for (offset, value) in [(8, UInt8(2)), (12, 9), (20, 255), (56, 0), (72 + 32, 0)] {
            var payload = Data(data.dropLast(32))
            if offset == 56 || offset == 104 { payload.replaceSubrange(offset..<(offset + 8), with: Data(count: 8)) }
            else { payload[offset] = value }
            payload.append(contentsOf: SHA256.hash(data: payload))
            #expect(throws: (any Error).self) { try RecordingChunkCodec.decode(payload) }
        }
    }

    @Test func metadataRejectsUnknownDuplicateSchemaAndChannelClaims() throws {
        let bytes = try RecordingChunkCodec.encodeMetadata(recordingMetadata())
        let text = String(decoding: bytes, as: UTF8.self)
        let invalid = [text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2"),
                       text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"schemaVersion\":1"),
                       text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"unknown\":0"),
                       text.replacingOccurrences(of: "coreMotionDeviceFrame", with: "unknownFrame"),
                       text.replacingOccurrences(of: "\"playingArmConfirmed\":true", with: "\"playingArmConfirmed\":false"),
                       text + " "]
        for value in invalid { #expect(throws: (any Error).self) { try RecordingChunkCodec.decodeMetadata(Data(value.utf8)) } }
    }

    @Test func validChecksumsStillRejectMalformedHeadersAndSourceTimestamps() throws {
        let original = try RecordingChunkCodec.encode(recordingChunk())
        let payload = Data(original.dropLast(32))
        func rechecksum(_ bytes: Data) -> Data { bytes + Data(SHA256.hash(data: bytes)) }
        func replacing32(_ offset: Int, with value: UInt32) -> Data {
            var changed = payload
            changed.replaceSubrange(offset..<(offset + 4),
                                    with: (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
            return rechecksum(changed)
        }
        func replaceTimestamp(_ bytes: inout Data, offset: Int, value: Double) {
            bytes.replaceSubrange(offset..<(offset + 8),
                                  with: (0..<8).map { UInt8(truncatingIfNeeded: value.bitPattern >> ($0 * 8)) })
        }

        #expect(throws: RecordingError.invalid("chunk schema or stream")) {
            try RecordingChunkCodec.decode(replacing32(8, with: 2))
        }
        #expect(throws: RecordingError.invalid("chunk schema or stream")) {
            try RecordingChunkCodec.decode(replacing32(12, with: 99))
        }
        for count: UInt32 in [0, 3, .max] {
            #expect(throws: RecordingError.integrity("chunk size or count")) {
                try RecordingChunkCodec.decode(replacing32(20, with: count))
            }
        }
        for sequence: UInt32 in [256, .max] {
            #expect(throws: RecordingError.invalid("chunk sequence")) {
                try RecordingChunkCodec.decode(replacing32(16, with: sequence))
            }
        }
        for boundOffset in [56, 64] {
            var changed = payload
            replaceTimestamp(&changed, offset: boundOffset, value: 42)
            #expect(throws: RecordingError.integrity("timestamp bounds")) {
                try RecordingChunkCodec.decode(rechecksum(changed))
            }
        }
        // Match the altered terminal bound to the altered payload timestamp so rejection
        // must reach source-sample validation, not the checksum or header-bound guard.
        for timestamp in [10.125, 10.0, Double.nan, .infinity, -.infinity] {
            var changed = payload
            replaceTimestamp(&changed, offset: 64, value: timestamp)
            replaceTimestamp(&changed, offset: 104, value: timestamp)
            #expect(throws: RecordingError.invalid("sample")) {
                try RecordingChunkCodec.decode(rechecksum(changed))
            }
        }
    }
}
