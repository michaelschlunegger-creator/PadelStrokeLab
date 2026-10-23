import Foundation

public enum MotionStatisticMetric: String, CaseIterable, Sendable {
    case userAcceleration, rotationRate, rawAcceleration

    public func displayValue(_ value: Double) -> Double? {
        let converted = self == .rotationRate ? value * (180 / .pi) : value
        return converted.isFinite ? converted : nil
    }
}

public struct MotionStatisticsSegment: Equatable, Sendable {
    public let id: Int
    public let start: Double
    public let end: Double
    public init(id: Int, start: Double, end: Double) {
        self.id = id; self.start = start; self.end = end
    }
}

public struct MotionStatisticsPoint: Equatable, Sendable {
    public let timestamp: Double
    public let value: Double
    public let segmentID: Int
}

public struct MotionStatisticSummary: Equatable, Sendable {
    public let metric: MotionStatisticMetric
    public let sampleCount: Int
    public let peak: Double?
    public let sampleRMS: Double?
    public let points: [MotionStatisticsPoint]
    public let unavailableReason: String?
}

public struct MotionStatistics: Equatable, Sendable {
    public let anchor: Double
    public let summaries: [MotionStatisticSummary]

    public func summary(for metric: MotionStatisticMetric) -> MotionStatisticSummary {
        // Every reducer result contains all three metrics, including unavailable ones.
        summaries.first { $0.metric == metric }!
    }
}

/// Synchronous, bounded interpretation of already verified chunks. Does not own files or capture.
public struct MotionStatisticsAccumulator: Sendable {
    private struct Plan: Sendable {
        let segment: MotionStatisticsSegment
        let offset: Int
        let count: Int
    }
    private struct Bucket: Sendable {
        var first: MotionStatisticsPoint?
        var minimum: MotionStatisticsPoint?
        var maximum: MotionStatisticsPoint?
        var last: MotionStatisticsPoint?

        mutating func add(_ point: MotionStatisticsPoint) {
            if first == nil { first = point }
            if minimum == nil || point.value < minimum!.value { minimum = point }
            if maximum == nil || point.value > maximum!.value { maximum = point }
            last = point
        }

        var points: [MotionStatisticsPoint] {
            var result: [MotionStatisticsPoint] = []
            for point in [first, minimum, maximum, last].compactMap({ $0 }).sorted(by: { $0.timestamp < $1.timestamp }) {
                if result.last != point { result.append(point) }
            }
            return result
        }
    }
    private struct MetricState: Sendable {
        var count = 0
        var scale = 0.0
        var scaledSquares = 0.0
        var representable = true
        var buckets: [Bucket]

        mutating func add(_ value: Double, timestamp: Double, segmentID: Int, bucket: Int) {
            count += 1
            guard representable else { return }
            guard value.isFinite else {
                representable = false
                buckets = []
                return
            }
            // Scaled sum of squares avoids squaring large finite magnitudes.
            if value > scale {
                let ratio = scale / value
                scaledSquares = scaledSquares * ratio * ratio + 1
                scale = value
            } else if scale > 0 {
                let ratio = value / scale
                scaledSquares += ratio * ratio
            }
            buckets[bucket].add(.init(timestamp: timestamp, value: value, segmentID: segmentID))
        }

        func summary(_ metric: MotionStatisticMetric) -> MotionStatisticSummary {
            guard count > 0 else {
                return .init(metric: metric, sampleCount: 0, peak: nil, sampleRMS: nil,
                             points: [], unavailableReason: "No eligible retained samples.")
            }
            guard representable, metric.displayValue(scale) != nil else {
                return .init(metric: metric, sampleCount: count, peak: nil, sampleRMS: nil,
                             points: [], unavailableReason: "Recorded values exceed the numerical display range.")
            }
            // RMS cannot exceed the largest magnitude; min only corrects floating-point roundoff.
            let rms = scale * sqrt(min(1, scaledSquares / Double(count)))
            return .init(metric: metric, sampleCount: count, peak: scale, sampleRMS: rms,
                         points: buckets.flatMap(\.points), unavailableReason: nil)
        }
    }

    private let metadata: RecordingMetadata
    private let plans: [Plan]
    private var metrics: [MotionStatisticMetric: MetricState]
    private var lastTimestamp: [RecordingStream: Double] = [:]
    private var lastSequence: [RecordingStream: Int] = [:]
    private var segmentCursor: [RecordingStream: Int] = [:]
    private var failed = false

    public init(metadata: RecordingMetadata, segments: [MotionStatisticsSegment], chartBucketBudget: Int = 256) throws {
        try metadata.validate()
        guard !segments.isEmpty, segments.count <= 256,
              (segments.count...256).contains(chartBucketBudget) else {
            throw RecordingError.limit("motion statistics segments or buckets")
        }
        var previousEnd = metadata.clock.monotonicAnchorSeconds
        var identifiers: Set<Int> = []
        for segment in segments {
            guard segment.id >= 0, identifiers.insert(segment.id).inserted,
                  segment.start.isFinite, segment.end.isFinite,
                  segment.start >= previousEnd, segment.end >= segment.start,
                  (segment.end - segment.start).isFinite else {
                throw RecordingError.invalid("motion statistics segments")
            }
            previousEnd = segment.end
        }
        let durations = segments.map { $0.end - $0.start }
        let longest = durations.max() ?? 0
        let weights = durations.map { longest > 0 ? $0 / longest : 0 }
        let totalWeight = weights.reduce(0, +)
        let spare = chartBucketBudget - segments.count
        let shares = weights.map { totalWeight > 0 ? $0 / totalWeight * Double(spare) : 0 }
        var allocation = shares.map { 1 + Int($0.rounded(.down)) }
        var remainder = chartBucketBudget - allocation.reduce(0, +)
        // All-zero duration intervals need only one bucket each.
        if totalWeight > 0 {
            let order = segments.indices.sorted {
                let a = shares[$0] - shares[$0].rounded(.down)
                let b = shares[$1] - shares[$1].rounded(.down)
                return a == b ? $0 < $1 : a > b
            }
            for index in order where remainder > 0 { allocation[index] += 1; remainder -= 1 }
        }
        var offset = 0
        plans = segments.indices.map { index in
            defer { offset += allocation[index] }
            return Plan(segment: segments[index], offset: offset, count: allocation[index])
        }
        self.metadata = metadata
        metrics = Dictionary(uniqueKeysWithValues: MotionStatisticMetric.allCases.map {
            ($0, MetricState(buckets: Array(repeating: Bucket(), count: offset)))
        })
    }

    public mutating func consume(
        _ chunk: RecordingChunk,
        checkCancellation: () throws -> Void = { try Task.checkCancellation() }
    ) throws {
        do {
            try checkCancellation()
            guard !failed, chunk.recordingID == metadata.recordingID,
                  chunk.clockDomainID == metadata.clock.domainID,
                  metadata.streams.contains(where: { $0.stream == chunk.stream && $0.supported }),
                  (0..<RecordingLimits.chunks).contains(chunk.sequence),
                  lastSequence[chunk.stream].map({ chunk.sequence > $0 }) ?? true,
                  !chunk.samples.isEmpty, chunk.samples.count <= chunk.stream.maximumSamples else {
                throw RecordingError.integrity("motion statistics chunk identity or order")
            }
            var cursor = segmentCursor[chunk.stream] ?? 0
            for (index, sample) in chunk.samples.enumerated() {
                if index.isMultiple(of: 256) { try checkCancellation() }
                // Validate EVERY input, before checking interval eligibility.
                guard sample.timestamp.isFinite, sample.timestamp >= 0,
                      sample.values.count == chunk.stream.componentCount,
                      sample.values.allSatisfy(\.isFinite),
                      lastTimestamp[chunk.stream].map({ sample.timestamp > $0 }) ?? true else {
                    throw RecordingError.integrity("motion statistics sample shape or order")
                }
                lastTimestamp[chunk.stream] = sample.timestamp
                while cursor < plans.count && sample.timestamp > plans[cursor].segment.end { cursor += 1 }
                guard cursor < plans.count, sample.timestamp >= plans[cursor].segment.start else { continue }
                let plan = plans[cursor]
                let duration = plan.segment.end - plan.segment.start
                let bin = duration > 0
                    ? min(plan.count - 1, Int((sample.timestamp - plan.segment.start) / duration * Double(plan.count))) : 0
                let values = sample.values
                func magnitude(_ start: Int) -> Double { hypot(hypot(values[start], values[start + 1]), values[start + 2]) }
                if chunk.stream == .accelerometer {
                    metrics[.rawAcceleration]!.add(magnitude(0), timestamp: sample.timestamp,
                        segmentID: plan.segment.id, bucket: plan.offset + bin)
                } else {
                    metrics[.rotationRate]!.add(magnitude(0), timestamp: sample.timestamp,
                        segmentID: plan.segment.id, bucket: plan.offset + bin)
                    metrics[.userAcceleration]!.add(magnitude(6), timestamp: sample.timestamp,
                        segmentID: plan.segment.id, bucket: plan.offset + bin)
                }
            }
            segmentCursor[chunk.stream] = cursor
            lastSequence[chunk.stream] = chunk.sequence
            try checkCancellation()
        } catch {
            failed = true
            throw error
        }
    }

    public func result() throws -> MotionStatistics {
        try Task.checkCancellation()
        guard !failed else { throw RecordingError.integrity("motion statistics incomplete reduction") }
        return .init(anchor: metadata.clock.monotonicAnchorSeconds,
                     summaries: MotionStatisticMetric.allCases.map { metrics[$0]!.summary($0) })
    }
}
