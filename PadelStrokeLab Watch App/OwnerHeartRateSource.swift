import Foundation
import HealthKit
import PadelCore

struct OwnerHeartRateNativeReading {
    let id: UUID
    let start: Date, end: Date
    let bpm: Double
    let provenance: OwnerHeartRateProvenance?
    let isLocalDevice: Bool, isUserEntered: Bool
}
@MainActor protocol OwnerHeartRateHardware: AnyObject {
    var localDevice: HKDevice { get }
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>, completion: @escaping @MainActor (String?) -> Void)
    func makeQuery(type: HKQuantityType, predicate: NSPredicate, anchor: HKQueryAnchor?, limit: Int,
        handler: @escaping @Sendable ([HKSample]?, Int, HKQueryAnchor?, String?) -> Void) -> HKAnchoredObjectQuery
    func execute(_ query: HKAnchoredObjectQuery)
    func stop(_ query: HKAnchoredObjectQuery)
    func read(_ sample: HKQuantitySample, watchInstallationEpoch: UUID) -> OwnerHeartRateNativeReading
}
/// Count callbacks before crossing actors. Closing scheduling cannot discard entered work.
nonisolated private final class OwnerHeartCallbackGate: @unchecked Sendable {
    private let lock = NSLock()
    private var open = true, count = 0
    func enter() -> Bool { lock.withLock { guard open else { return false }; count += 1; return true } }
    func leave() { lock.withLock { count -= 1 } }
    func close() { lock.withLock { open = false } }
    var pending: Int { lock.withLock { count } }
}
@MainActor final class OwnerHeartRateSource {
    private let hardware: any OwnerHeartRateHardware
    private var generation = UUID(), gate = OwnerHeartCallbackGate()
    private var retiredGates: [OwnerHeartCallbackGate] = []
    private var query: HKAnchoredObjectQuery?, anchor: HKQueryAnchor?
    private var header: OwnerTelemetryHeader?
    private var busy = false, requested = false, stopped = true
    private var timer: Task<Void, Never>?
    private var publish: (([OwnerHeartRateSample], [OwnerTelemetryReason: Int], OwnerTelemetryInstant) async throws -> Void)?
    var onMessage: ((String) -> Void)?
    var onInterruption: ((OwnerTelemetryReason) -> Void)?
    var pendingCallbacks: Int { gate.pending + retiredGates.reduce(0) { $0 + $1.pending } }
    init() { hardware = NativeOwnerHeartRateHardware() }
    init(hardware: any OwnerHeartRateHardware, environment: WatchRuntimeEnvironment) throws {
        guard environment.isCoherentFixture else { throw OwnerCaptureFailure.unavailable }
        self.hardware = hardware
    }
    isolated deinit { timer?.cancel() }
    func begin(header: OwnerTelemetryHeader,
        publish: @escaping ([OwnerHeartRateSample], [OwnerTelemetryReason: Int], OwnerTelemetryInstant) async throws -> Void) {
        stop(); retiredGates.removeAll { $0.pending == 0 }
        if gate.pending > 0 { retiredGates.append(gate) }
        generation = UUID(); gate = OwnerHeartCallbackGate(); anchor = nil
        self.header = header; self.publish = publish; stopped = false; busy = false; requested = false
        let token = generation
        hardware.requestAuthorization(toShare: [], read: [HKObjectType.quantityType(forIdentifier: .heartRate)!]) { [weak self] error in
            guard let self, self.generation == token, !self.stopped else { return }
            if let error { self.onMessage?(error); self.stop(); return }
            self.onMessage?("No accessible heart-rate data")
            self.wake()
            self.timer = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    self?.wake()
                }
            }
        }
    }
    func wake() {
        guard !stopped, let header else { return }
        guard !busy else { requested = true; return }
        busy = true; requested = false
        let token = generation, callbackGate = gate, publication = publish
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: Date(timeIntervalSince1970: header.clock.wallAnchorUnixSeconds),
                end: Date(timeIntervalSince1970: header.clock.wallAnchorUnixSeconds + 1800), options: .strictStartDate),
            HKQuery.predicateForObjects(from: [hardware.localDevice])])
        let query = hardware.makeQuery(type: HKObjectType.quantityType(forIdentifier: .heartRate)!, predicate: predicate,
            anchor: anchor, limit: 256) { [weak self] samples, deleted, next, error in
            guard callbackGate.enter() else { return }
            // Capture both clocks before crossing actors; publication keeps the genuine callback entry.
            let enteredAt = Date()
            let enteredMonotonic = ProcessInfo.processInfo.systemUptime
            Task { @MainActor [weak self] in
                defer { callbackGate.leave() }
                guard let self else { return }
                await self.receive(samples ?? [], deleted: deleted, next: next, error: error, header: header, token: token, enteredAt: enteredAt,
                    enteredMonotonic: enteredMonotonic, publication: publication)
            }
        }
        self.query = query; hardware.execute(query)
    }
    private func receive(_ samples: [HKSample], deleted: Int, next: HKQueryAnchor?, error: String?, header: OwnerTelemetryHeader,
        token: UUID, enteredAt: Date, enteredMonotonic: Double, publication: (([OwnerHeartRateSample], [OwnerTelemetryReason: Int], OwnerTelemetryInstant) async throws -> Void)?) async {
        var reasons: [OwnerTelemetryReason: Int] = [:], accepted: [OwnerHeartRateSample] = []
        if error != nil { reasons[.sourceError] = 1 }
        else if deleted < 0 || samples.count > 256 || deleted > 256 - samples.count { reasons[.pageLimit] = 1 }
        else {
            if deleted > 0 { reasons[.sourceDeleted] = deleted }
            for sample in samples {
                guard let quantity = sample as? HKQuantitySample else { reasons[.sourceError, default: 0] += 1; continue }
                let reading = hardware.read(quantity, watchInstallationEpoch: header.watchInstallationEpoch)
                let reason: OwnerTelemetryReason?
                if reading.isUserEntered { reason = .userEntered }
                else if !reading.isLocalDevice { reason = .mismatchedProvenance }
                else if reading.provenance == nil { reason = .missingProvenance }
                else if ![reading.start.timeIntervalSince1970, reading.end.timeIntervalSince1970].allSatisfy({ $0.isFinite }) { reason = .invalidDate }
                else if reading.start > reading.end { reason = .unorderedInterval }
                else if reading.start.timeIntervalSince1970 < header.clock.wallAnchorUnixSeconds ||
                    reading.end.timeIntervalSince1970 > header.clock.wallAnchorUnixSeconds + 1800 { reason = .outsidePractice }
                else if !reading.bpm.isFinite || reading.bpm <= 0 || reading.bpm > 300 { reason = .bpmOutOfRange }
                else if reading.end > enteredAt { reason = .incompleteObservation }
                else { reason = nil }
                if let reason { reasons[reason, default: 0] += 1; continue }
                accepted.append(OwnerHeartRateSample(id: reading.id, bpm: reading.bpm, sourceStart: reading.start,
                    sourceEnd: reading.end, arrival: enteredAt, provenance: reading.provenance!))
            }
        }
        let fatal = reasons.keys.contains { [.sourceDeleted, .sourceError, .pageLimit].contains($0) }
        do {
            let entry = try OwnerTelemetryInstant(wallUnixSeconds: enteredAt.timeIntervalSince1970, monotonicSeconds: enteredMonotonic)
            try await publication?(accepted, reasons, entry)
            guard generation == token else { return }
            anchor = next // Only durable publication authorizes this anchor.
            if !accepted.isEmpty { onMessage?("Observed heart-rate samples") }
        } catch {
            guard generation == token else { return }
            onMessage?("Heart-rate evidence could not be saved."); stop(); onInterruption?(.sourceError)
        }
        busy = false; query = nil
        if fatal {
            stop()
            if let reason = [OwnerTelemetryReason.pageLimit, .sourceDeleted, .sourceError].first(where: { reasons[$0] != nil }) { onInterruption?(reason) }
            return
        }
        if !stopped && (requested || samples.count + deleted == 256) { wake() }
    }
    func stop() {
        stopped = true; requested = false; timer?.cancel(); timer = nil; gate.close()
        if let query { hardware.stop(query) }
    }
}
@MainActor private final class NativeOwnerHeartRateHardware: OwnerHeartRateHardware {
    private let health = HKHealthStore()
    let localDevice = HKDevice.local()
    func requestAuthorization(toShare: Set<HKSampleType>, read: Set<HKObjectType>, completion: @escaping @MainActor (String?) -> Void) {
        health.requestAuthorization(toShare: toShare, read: read) { success, error in
            let message = error?.localizedDescription
            Task { @MainActor in completion(success ? nil : message ?? "Heart-rate access request could not complete.") }
        }
    }
    func makeQuery(type: HKQuantityType, predicate: NSPredicate, anchor: HKQueryAnchor?, limit: Int,
        handler: @escaping @Sendable ([HKSample]?, Int, HKQueryAnchor?, String?) -> Void) -> HKAnchoredObjectQuery {
        HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: anchor, limit: limit) { _, samples, deleted, next, error in
            handler(samples, deleted?.count ?? 0, next, error?.localizedDescription)
        }
    }
    func execute(_ query: HKAnchoredObjectQuery) { health.execute(query) }
    func stop(_ query: HKAnchoredObjectQuery) { health.stop(query) }
    func read(_ sample: HKQuantitySample, watchInstallationEpoch: UUID) -> OwnerHeartRateNativeReading {
        let revision = sample.sourceRevision, device = sample.device
        let version = revision.operatingSystemVersion
        let provenance = try? OwnerHeartRateProvenance(sourceBundleIdentifier: revision.source.bundleIdentifier,
            sourceVersion: revision.version ?? "unknown", operatingSystem: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            productType: revision.productType ?? "unknown", manufacturer: device?.manufacturer ?? "unknown", model: device?.model ?? "unknown",
            hardwareVersion: device?.hardwareVersion ?? "unknown", softwareVersion: device?.softwareVersion ?? "unknown",
            watchInstallationEpoch: watchInstallationEpoch)
        return OwnerHeartRateNativeReading(id: sample.uuid, start: sample.startDate, end: sample.endDate,
            bpm: sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())), provenance: provenance,
            isLocalDevice: device?.isEqual(localDevice) == true, isUserEntered: sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool == true)
    }
}
