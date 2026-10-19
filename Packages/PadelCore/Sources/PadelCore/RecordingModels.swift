import Foundation

/// Engineering limits, not measured sensor rates or supported recording durations.
public enum RecordingLimits {
    public static let chunkBytes = 1_048_576
    public static let metadataBytes = 16_384
    public static let manifestBytes = 262_144
    public static let textBytes = 128
    public static let chunks = 256
    public static let directoryEntries = 272
    public static let inspectionBytes = 268_976_128
}

public enum RecordingError: Error, Equatable, Sendable {
    case invalid(String)
    case limit(String)
    case integrity(String)
    case io(operation: String, code: Int32)
    case closed
    case finalized
}

public enum RecordingStream: UInt32, Codable, CaseIterable, Sendable {
    case accelerometer = 1
    case deviceMotion = 2

    public var components: [String] {
        switch self {
        case .accelerometer: ["acceleration.x", "acceleration.y", "acceleration.z"]
        case .deviceMotion:
            ["rotationRate.x", "rotationRate.y", "rotationRate.z",
             "gravity.x", "gravity.y", "gravity.z",
             "userAcceleration.x", "userAcceleration.y", "userAcceleration.z",
             "attitude.x", "attitude.y", "attitude.z", "attitude.w"]
        }
    }

    public var units: [String] {
        self == .accelerometer ? Array(repeating: "g", count: 3)
            : Array(repeating: "rad/s", count: 3) + Array(repeating: "g", count: 6)
                + Array(repeating: "unitless", count: 4)
    }

    public var componentCount: Int { self == .accelerometer ? 3 : 13 }
    public var maximumSamples: Int { (RecordingLimits.chunkBytes - 104) / ((componentCount + 1) * 8) }
}

public struct RecordingClock: Codable, Equatable, Sendable {
    /// Identifies this capture's source clock domain. Never reused to resume a reopened recording.
    public let domainID: UUID
    public let monotonicAnchorSeconds: Double
    public let wallAnchorUnixSeconds: Double

    public init(domainID: UUID, monotonicAnchorSeconds: Double, wallAnchorUnixSeconds: Double) throws {
        self.domainID = domainID
        self.monotonicAnchorSeconds = monotonicAnchorSeconds
        self.wallAnchorUnixSeconds = wallAnchorUnixSeconds
        try validate()
    }

    func validate() throws {
        guard monotonicAnchorSeconds.isFinite, monotonicAnchorSeconds >= 0,
              wallAnchorUnixSeconds.isFinite else { throw RecordingError.invalid("clock anchor") }
    }
}

public struct RecordingStreamConfiguration: Codable, Equatable, Sendable {
    public let stream: RecordingStream
    public let supported: Bool
    /// Supplied request, not an observed rate. Unknown values stay nil.
    public let requestedRateHz: Double?
    public let knownSensorLimit: Double?
    public let components: [String]
    public let units: [String]
    public let coordinateConvention: String

    public init(stream: RecordingStream, supported: Bool, requestedRateHz: Double?, knownSensorLimit: Double?) throws {
        self.stream = stream
        self.supported = supported
        self.requestedRateHz = requestedRateHz
        self.knownSensorLimit = knownSensorLimit
        components = stream.components
        units = stream.units
        coordinateConvention = "coreMotionDeviceFrame"
        try validate()
    }

    func validate() throws {
        for number in [requestedRateHz, knownSensorLimit].compactMap({ $0 }) {
            guard number.isFinite, number > 0 else { throw RecordingError.invalid("stream configuration") }
        }
        guard components == stream.components, units == stream.units,
              coordinateConvention == "coreMotionDeviceFrame" else {
            throw RecordingError.invalid("channel definition")
        }
    }
}

/// Supplied setup/capability facts; the storage layer does not discover or invent device facts.
public struct RecordingMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let recordingID: UUID
    public let clock: RecordingClock
    public let appBuild: String
    public let protocolVersion: String
    public let deviceModel: String
    public let operatingSystem: String
    public let handedness: PlayingArm
    public let playingArm: PlayingArm
    public let watchWrist: PlayingArm
    public let watchOrientation: String
    public let playingArmConfirmed: Bool
    public let drill: String
    public let capabilityReport: String
    public let streams: [RecordingStreamConfiguration]

    public init(recordingID: UUID, clock: RecordingClock, appBuild: String, protocolVersion: String,
                deviceModel: String, operatingSystem: String, handedness: PlayingArm,
                playingArm: PlayingArm, watchWrist: PlayingArm, watchOrientation: String,
                playingArmConfirmed: Bool, drill: String, capabilityReport: String,
                streams: [RecordingStreamConfiguration]) throws {
        schemaVersion = 1
        self.recordingID = recordingID
        self.clock = clock
        self.appBuild = appBuild
        self.protocolVersion = protocolVersion
        self.deviceModel = deviceModel
        self.operatingSystem = operatingSystem
        self.handedness = handedness
        self.playingArm = playingArm
        self.watchWrist = watchWrist
        self.watchOrientation = watchOrientation
        self.playingArmConfirmed = playingArmConfirmed
        self.drill = drill
        self.capabilityReport = capabilityReport
        self.streams = streams
        try validate()
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw RecordingError.invalid("metadata schema") }
        try clock.validate()
        for value in [appBuild, protocolVersion, deviceModel, operatingSystem, watchOrientation, drill, capabilityReport] {
            guard !value.isEmpty, value.utf8.count <= RecordingLimits.textBytes,
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw RecordingError.invalid("metadata text")
            }
        }
        guard playingArmConfirmed, playingArm == watchWrist else { throw RecordingError.invalid("playing arm setup") }
        guard !streams.isEmpty, streams.count <= RecordingStream.allCases.count,
              Set(streams.map(\.stream)).count == streams.count else { throw RecordingError.invalid("stream declarations") }
        for stream in streams { try stream.validate() }
    }
}

public struct RecordingSample: Equatable, Sendable {
    /// Original source seconds and components. Double bit patterns survive the binary codec.
    public let timestamp: Double
    public let values: [Double]

    public init(timestamp: Double, values: [Double]) {
        self.timestamp = timestamp
        self.values = values
    }
}

public struct RecordingChunk: Equatable, Sendable {
    public let recordingID: UUID
    public let clockDomainID: UUID
    public let stream: RecordingStream
    public let sequence: Int
    public let samples: [RecordingSample]

    public init(recordingID: UUID, clockDomainID: UUID, stream: RecordingStream,
                sequence: Int, samples: [RecordingSample]) throws {
        self.recordingID = recordingID
        self.clockDomainID = clockDomainID
        self.stream = stream
        self.sequence = sequence
        self.samples = samples
        try validate()
    }

    func validate() throws {
        guard sequence >= 0, sequence < RecordingLimits.chunks else { throw RecordingError.invalid("chunk sequence") }
        guard !samples.isEmpty, samples.count <= stream.maximumSamples else { throw RecordingError.limit("sample count") }
        var previous: Double?
        for sample in samples {
            guard sample.timestamp.isFinite, sample.timestamp >= 0,
                  previous.map({ sample.timestamp > $0 }) ?? true,
                  sample.values.count == stream.componentCount,
                  sample.values.allSatisfy(\.isFinite) else { throw RecordingError.invalid("sample") }
            previous = sample.timestamp
        }
    }
}

public struct RecordingChunkDescriptor: Codable, Equatable, Sendable {
    public let stream: RecordingStream
    public let sequence: Int
    public let sampleCount: Int
    public let firstTimestamp: Double
    public let lastTimestamp: Double
    public let byteCount: Int
    public let sha256: String

    public var fileName: String { "chunk-\(stream.rawValue)-\(sequence).bin" }
}

public struct RecordingCoverage: Codable, Equatable, Sendable {
    public let stream: RecordingStream
    public let sampleCount: Int
    public let firstTimestamp: Double
    public let lastTimestamp: Double
}

public enum RecordingStopReason: String, Codable, Sendable {
    case userStopped, interrupted, failed
}

public struct RecordingFinalization: Codable, Equatable, Sendable {
    public let stopRequestTimestamp: Double
    public let reason: RecordingStopReason
    /// Retained bounds only: gaps and the unobserved stop tail are not declared continuous.
    public let retainedCoverage: [RecordingCoverage]
}

public enum RecordingRecoveryStatus: String, Sendable {
    case finalized, interrupted, corrupt, limited
}

public struct RecordingRecoveryIssue: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case missing, corrupt, inconsistent, orphan, partial, unexpected, limit
    }
    public let kind: Kind
    public let fileName: String
}

public struct RecordingRecoveryReport: Sendable {
    public let metadata: RecordingMetadata?
    public let status: RecordingRecoveryStatus
    public let chunks: [RecordingChunkDescriptor]
    public let finalization: RecordingFinalization?
    public let issues: [RecordingRecoveryIssue]
}

public struct RecordingInspectionBudget: Sendable {
    public let maximumEntries: Int
    public let maximumBytes: Int

    public init(maximumEntries: Int = RecordingLimits.directoryEntries,
                maximumBytes: Int = RecordingLimits.inspectionBytes) throws {
        guard (1...RecordingLimits.directoryEntries).contains(maximumEntries),
              (1...RecordingLimits.inspectionBytes).contains(maximumBytes) else { throw RecordingError.limit("inspection budget") }
        self.maximumEntries = maximumEntries
        self.maximumBytes = maximumBytes
    }
}
