import Foundation

/// Versioned metadata encoding. Raw sensor streams are deliberately not handled here.
public enum PracticeArchive {
    public static let maximumMetadataBytes = 1_048_576

    public static func encode(_ session: PracticeSession) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(session)
        guard data.count <= maximumMetadataBytes else { throw PracticeValidationError.archiveTooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> PracticeSession {
        guard data.count <= maximumMetadataBytes else { throw PracticeValidationError.archiveTooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(PracticeSession.self, from: data)
    }
}
