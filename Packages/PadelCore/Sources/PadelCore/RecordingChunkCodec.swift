import CryptoKit
import Foundation

/// Schema 1 is little-endian, with a checksum-protected (not signed) header/payload.
/// The checksum detects accidental corruption; it cannot authenticate a maliciously rewritten archive.
public enum RecordingChunkCodec {
    private static let magic = Data("PSLRAW01".utf8)

    public static func encode(_ chunk: RecordingChunk) throws -> Data {
        try chunk.validate()
        var data = Data()
        data.reserveCapacity(104 + chunk.samples.count * (chunk.stream.componentCount + 1) * 8)
        data.append(magic)
        append(UInt32(1), to: &data)
        append(chunk.stream.rawValue, to: &data)
        append(UInt32(chunk.sequence), to: &data)
        append(UInt32(chunk.samples.count), to: &data)
        append(chunk.recordingID, to: &data)
        append(chunk.clockDomainID, to: &data)
        append(chunk.samples[0].timestamp.bitPattern, to: &data)
        append(chunk.samples[chunk.samples.count - 1].timestamp.bitPattern, to: &data)
        for sample in chunk.samples {
            append(sample.timestamp.bitPattern, to: &data)
            for value in sample.values { append(value.bitPattern, to: &data) }
        }
        data.append(contentsOf: SHA256.hash(data: data))
        guard data.count <= RecordingLimits.chunkBytes else { throw RecordingError.limit("chunk bytes") }
        return data
    }

    public static func decode(_ data: Data) throws -> RecordingChunk {
        guard data.count <= RecordingLimits.chunkBytes else { throw RecordingError.limit("chunk bytes") }
        guard data.count >= 104, data.prefix(8) == magic else { throw RecordingError.integrity("chunk header") }
        guard Data(SHA256.hash(data: data.dropLast(32))) == data.suffix(32) else {
            throw RecordingError.integrity("chunk checksum")
        }
        var reader = Reader(data: data, offset: 8)
        guard try reader.u32() == 1, let stream = RecordingStream(rawValue: try reader.u32()) else {
            throw RecordingError.invalid("chunk schema or stream")
        }
        let sequence = Int(try reader.u32())
        let count = Int(try reader.u32())
        guard count > 0, count <= stream.maximumSamples,
              data.count == 104 + count * (stream.componentCount + 1) * 8 else {
            throw RecordingError.integrity("chunk size or count")
        }
        let recordingID = try reader.uuid()
        let clockID = try reader.uuid()
        let firstBits = try reader.u64()
        let lastBits = try reader.u64()
        var samples: [RecordingSample] = []
        samples.reserveCapacity(count)
        for _ in 0..<count {
            let timestamp = Double(bitPattern: try reader.u64())
            var values: [Double] = []
            values.reserveCapacity(stream.componentCount)
            for _ in 0..<stream.componentCount { values.append(Double(bitPattern: try reader.u64())) }
            samples.append(RecordingSample(timestamp: timestamp, values: values))
        }
        guard samples[0].timestamp.bitPattern == firstBits, samples[count - 1].timestamp.bitPattern == lastBits else {
            throw RecordingError.integrity("timestamp bounds")
        }
        return try RecordingChunk(recordingID: recordingID, clockDomainID: clockID,
                                  stream: stream, sequence: sequence, samples: samples)
    }

    public static func encodeMetadata(_ metadata: RecordingMetadata) throws -> Data {
        try metadata.validate()
        return try RecordingJSON.encode(metadata, limit: RecordingLimits.metadataBytes)
    }

    public static func decodeMetadata(_ data: Data) throws -> RecordingMetadata {
        let metadata: RecordingMetadata = try RecordingJSON.decode(data, limit: RecordingLimits.metadataBytes)
        try metadata.validate()
        return metadata
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func descriptor(_ chunk: RecordingChunk, data: Data) -> RecordingChunkDescriptor {
        RecordingChunkDescriptor(stream: chunk.stream, sequence: chunk.sequence, sampleCount: chunk.samples.count,
                                 firstTimestamp: chunk.samples[0].timestamp,
                                 lastTimestamp: chunk.samples[chunk.samples.count - 1].timestamp,
                                 byteCount: data.count, sha256: digest(data))
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private static func append(_ value: UUID, to data: inout Data) {
        var bytes = value.uuid
        withUnsafeBytes(of: &bytes) { data.append(contentsOf: $0) }
    }

    private struct Reader {
        let data: Data
        var offset: Int

        mutating func number<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
            let size = MemoryLayout<T>.size
            guard offset <= data.count - size else { throw RecordingError.integrity("truncated number") }
            let result = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
            offset += size
            return T(littleEndian: result)
        }

        mutating func u32() throws -> UInt32 { try number(UInt32.self) }
        mutating func u64() throws -> UInt64 { try number(UInt64.self) }
        mutating func uuid() throws -> UUID {
            guard offset <= data.count - 16 else { throw RecordingError.integrity("truncated UUID") }
            let bytes = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: uuid_t.self) }
            offset += 16
            return UUID(uuid: bytes)
        }
    }
}

/// Only canonical, bounded encodings are accepted. Re-encoding rejects ignored keys, duplicate keys,
/// alternate scalar encodings and trailing bytes without a permissive JSON migration path.
enum RecordingJSON {
    static func encode<T: Encodable>(_ value: T, limit: Int) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= limit else { throw RecordingError.limit("JSON bytes") }
        return data
    }

    static func decode<T: Codable>(_ data: Data, limit: Int) throws -> T {
        guard data.count <= limit else { throw RecordingError.limit("JSON bytes") }
        let result = try JSONDecoder().decode(T.self, from: data)
        guard try encode(result, limit: limit) == data else { throw RecordingError.integrity("noncanonical JSON") }
        return result
    }
}
