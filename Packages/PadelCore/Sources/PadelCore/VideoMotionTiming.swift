import Foundation

/// Four actual monotonic-clock observations. No assumption of symmetric network latency.
public struct VideoMotionClockExchange: Codable, Equatable, Sendable {
    public let id: UUID
    public let phoneEpoch: UUID
    public let watchEpoch: UUID
    public let phoneSent: Double
    public let watchReceived: Double
    public let watchSent: Double
    public let phoneReceived: Double

    public init(id: UUID = UUID(), phoneEpoch: UUID, watchEpoch: UUID, phoneSent: Double,
                watchReceived: Double, watchSent: Double, phoneReceived: Double) throws {
        self.id = id; self.phoneEpoch = phoneEpoch; self.watchEpoch = watchEpoch
        self.phoneSent = phoneSent; self.watchReceived = watchReceived
        self.watchSent = watchSent; self.phoneReceived = phoneReceived
        try validate()
    }

    public var offsetLowerBound: Double { watchSent - phoneReceived }
    public var offsetUpperBound: Double { watchReceived - phoneSent }
    public var networkRoundTrip: Double { (phoneReceived - phoneSent) - (watchSent - watchReceived) }
    public var phoneMidpoint: Double { phoneSent + (phoneReceived - phoneSent) / 2 }

    func validate() throws {
        guard [phoneSent, watchReceived, watchSent, phoneReceived].allSatisfy(VideoMotionTime.valid),
              phoneReceived >= phoneSent, watchSent >= watchReceived,
              networkRoundTrip >= 0, offsetLowerBound <= offsetUpperBound else {
            throw VideoMotionError.invalid("clock exchange")
        }
    }
}

public struct VideoMotionTimeEstimate: Equatable, Sendable {
    public let timestamp: Double
    public let uncertaintySeconds: Double
}

/// A bounded, conditional affine-clock estimate, reconstructed from observations when read.
/// Its interval is mathematical uncertainty under that model, not measured device accuracy.
/// It neither extrapolates nor replaces native capture-clock/player-time conversion.
public struct VideoMotionClockMapping: Codable, Equatable, Sendable {
    public static let maximumExchanges = 32
    public static let maximumBytes = 32_768
    public static let minimumDriftSpanSeconds: Double = 5
    private let schemaVersion: Int
    public let id: UUID
    public let exchanges: [VideoMotionClockExchange]
    public var phoneEpoch: UUID { exchanges[0].phoneEpoch }
    public var watchEpoch: UUID { exchanges[0].watchEpoch }

    public init(id: UUID = UUID(), exchanges: [VideoMotionClockExchange]) throws {
        schemaVersion = 1; self.id = id; self.exchanges = exchanges
        try validate()
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        id = try values.decode(UUID.self, forKey: .id)
        exchanges = try values.decode([VideoMotionClockExchange].self, forKey: .exchanges)
        try validate()
    }

    public var driftPPMRange: ClosedRange<Double>? {
        guard enoughEvidence, let rates = try? rateBounds() else { return nil }
        return ((rates.lowerBound - 1) * 1_000_000)...((rates.upperBound - 1) * 1_000_000)
    }

    private var enoughEvidence: Bool {
        exchanges.count >= 3 && exchanges[exchanges.count - 1].phoneMidpoint - exchanges[0].phoneMidpoint
            >= Self.minimumDriftSpanSeconds
    }

    func validate() throws {
        guard schemaVersion == 1, !exchanges.isEmpty, exchanges.count <= Self.maximumExchanges else {
            throw VideoMotionError.invalid("clock observation count/version")
        }
        var ids = Set<UUID>()
        for (index, value) in exchanges.enumerated() {
            try value.validate()
            guard value.phoneEpoch == phoneEpoch, value.watchEpoch == watchEpoch,
                  ids.insert(value.id).inserted else { throw VideoMotionError.integrity }
            if index > 0 {
                let previous = exchanges[index - 1]
                guard value.phoneSent > previous.phoneReceived, value.watchReceived > previous.watchSent else {
                    throw VideoMotionError.invalid("reordered clock observations")
                }
            }
        }
        if enoughEvidence { _ = try rateBounds() }
    }

    /// For W = rate * P + intercept, causality gives
    /// watchSent - rate * phoneReceived <= intercept <= watchReceived - rate * phoneSent.
    /// Intersect every lower/upper pair, retaining drift during each exchange as well.
    private func rateBounds() throws -> ClosedRange<Double> {
        var lower = Double.leastNonzeroMagnitude, upper = Double.infinity
        for left in exchanges {
            for right in exchanges {
                let elapsed = left.phoneReceived - right.phoneSent
                let difference = left.watchSent - right.watchReceived
                if elapsed > 0 { lower = max(lower, difference / elapsed) }
                else if elapsed < 0 { upper = min(upper, difference / elapsed) }
                else if difference > 0 { throw VideoMotionError.invalid("inconsistent clocks") }
            }
        }
        guard lower.isFinite, upper.isFinite, lower > 0, lower <= upper else {
            throw VideoMotionError.invalid("inconsistent or unsupported clock rate")
        }
        return lower...upper
    }

    public func estimateWatch(atPhone timestamp: Double) throws -> VideoMotionTimeEstimate {
        try validate()
        guard enoughEvidence, VideoMotionTime.valid(timestamp),
              timestamp >= exchanges[0].phoneSent,
              timestamp <= exchanges[exchanges.count - 1].phoneReceived else {
            throw VideoMotionError.invalid("unsupported clock coverage")
        }
        let rates = try rateBounds()
        var lower = -Double.infinity, upper = Double.infinity
        for value in exchanges {
            let deltaLower = timestamp - value.phoneReceived, deltaUpper = timestamp - value.phoneSent
            lower = max(lower, value.watchSent + min(rates.lowerBound * deltaLower, rates.upperBound * deltaLower))
            upper = min(upper, value.watchReceived + max(rates.lowerBound * deltaUpper, rates.upperBound * deltaUpper))
        }
        return try estimate(lower, upper)
    }

    public func estimatePhone(atWatch timestamp: Double) throws -> VideoMotionTimeEstimate {
        try validate()
        guard enoughEvidence, VideoMotionTime.valid(timestamp) else {
            throw VideoMotionError.invalid("unsupported clock coverage")
        }
        let rates = try rateBounds()
        var lower = -Double.infinity, upper = Double.infinity
        for value in exchanges {
            let deltaLower = timestamp - value.watchReceived, deltaUpper = timestamp - value.watchSent
            lower = max(lower, value.phoneSent + min(deltaLower / rates.lowerBound, deltaLower / rates.upperBound))
            upper = min(upper, value.phoneReceived + max(deltaUpper / rates.lowerBound, deltaUpper / rates.upperBound))
        }
        guard lower >= exchanges[0].phoneSent, upper <= exchanges[exchanges.count - 1].phoneReceived else {
            throw VideoMotionError.invalid("unsupported clock coverage")
        }
        return try estimate(lower, upper)
    }

    private func estimate(_ lower: Double, _ upper: Double) throws -> VideoMotionTimeEstimate {
        guard lower.isFinite, upper.isFinite, lower >= 0, lower <= upper else {
            throw VideoMotionError.invalid("inconsistent clock estimate")
        }
        return VideoMotionTimeEstimate(timestamp: lower + (upper - lower) / 2,
                                       uncertaintySeconds: (upper - lower) / 2)
    }

    public func encoded() throws -> Data {
        try validate()
        return try OwnerCanonical.encode(self, domain: "PSLVideoMotionClock1", limit: Self.maximumBytes)
    }

    public static func decode(_ data: Data) throws -> Self {
        let value: Self = try OwnerCanonical.decode(data, domain: "PSLVideoMotionClock1", limit: maximumBytes)
        try value.validate(); return value
    }
}

enum VideoMotionTime {
    static func valid(_ value: Double) -> Bool { value.isFinite && value >= 0 && value <= 1_000_000_000_000 }
}
