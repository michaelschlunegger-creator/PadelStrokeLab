import Foundation
import PadelCore

/// Phone authority is retained separately from the brief, per-set physical checks.
struct WatchPreparationState {
    enum Step { case check }
    private(set) var step: Step?
    private(set) var accepted: OwnerPreparation?
    private(set) var placementConfirmed = false
    private(set) var orientationConfirmed = false
    private(set) var fitConfirmed = false
    var arm: PlayingArm? { accepted?.draft.preferences.currentRacketArm }
    var usualHand: PlayingArm? { accepted?.draft.preferences.usualHand }
    var drill: RecordingDrill? { accepted?.draft.preferences.intendedDrill }
    var drillRawValue: String? { drill?.rawValue }
    var finalConfirmed: Bool { placementConfirmed && orientationConfirmed && fitConfirmed }
    var isComplete: Bool { accepted != nil && step == .check && finalConfirmed }

    mutating func adopt(_ value: OwnerPreparation?) {
        guard accepted != value else { return }
        accepted = value
        reset()
    }
    mutating func begin() {
        reset()
        if accepted != nil { step = .check }
    }
    mutating func reset() { step = nil; invalidatePhysical() }
    mutating func invalidatePhysical() {
        placementConfirmed = false; orientationConfirmed = false; fitConfirmed = false
    }
    mutating func orientationChanged() { invalidatePhysical() }
    mutating func confirmPlacement() {
        guard step == .check, accepted != nil else { return }
        placementConfirmed = true
    }
    mutating func confirmOrientation(wrist: PlayingArm?) {
        guard step == .check, placementConfirmed, let wrist, wrist == arm else { return }
        orientationConfirmed = true
    }
    mutating func confirmFit() {
        guard step == .check, orientationConfirmed else { return }
        fitConfirmed = true
    }
    mutating func consume() -> Bool {
        guard isComplete else { return false }
        reset(); return true
    }
}
