/// Explicit versioned acquisition intent. Absence preserves the original motion-only contract.
/// This is preparation metadata, not permission to start either device or proof of video capture.
public enum RecordingCaptureMode: String, Codable, Equatable, Sendable {
    case videoMotionMixedReferenceV1

    public var protocolVersion: String {
        switch self {
        case .videoMotionMixedReferenceV1: "owner-video-motion-mixed-reference-1"
        }
    }
}

/// Manual intent for new short training sets. This is not a detected stroke or contact label.
/// Historical recording metadata remains free-form and is never migrated through this vocabulary.
public enum RecordingDrill: String, CaseIterable, Identifiable, Sendable {
    case forehandGroundstroke, backhandGroundstroke, forehandVolley, backhandVolley
    case serve, lob, bandeja, vibora, smash, otherUnclassified

    public static let protocolVersion = "owner-manual-training-logger-1"
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .forehandGroundstroke: "Forehand groundstroke"
        case .backhandGroundstroke: "Backhand groundstroke"
        case .forehandVolley: "Forehand volley"
        case .backhandVolley: "Backhand volley"
        case .serve: "Serve"
        case .lob: "Lob"
        case .bandeja: "Bandeja"
        case .vibora: "Víbora"
        case .smash: "Smash"
        case .otherUnclassified: "Other / unclassified"
        }
    }

    /// Recognizes the original forehand raw value without altering its original protocol or bytes.
    public static func recordedTitle(for rawValue: String) -> String {
        Self(rawValue: rawValue)?.title ?? "Unrecognized recorded value: \(rawValue)"
    }
}
