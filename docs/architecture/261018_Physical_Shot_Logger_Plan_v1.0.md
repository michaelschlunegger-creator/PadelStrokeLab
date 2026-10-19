# Physical shot logger — Codex/Astra plan

18 October 2026, Asia/Dubai. **Planning precedes implementation.** Owner direction: implement everything needed to physically test shots, use Astra, and plan the motion work first in Codex. This supersedes the earlier storage-only delivery boundary. The owner has authorized the complete tester; the following packages are internal engineering stages, not repeated owner approval stops.

## Starting authority and review

Authority: PSL-SPEC-001 v1.1 S1-01–10, WP1, T01–05/T15–16. Repo `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, current local branch `feature/watch-recording-storage`, HEAD `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, no upstream. Preserve the existing uncommitted storage implementation/docs (64 host tests and both Release builds previously passed). Foundation remote remains at that HEAD; remote main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. No main edits, merge, release or destructive Git operation.

Xcode 27.0 (27A266a), iOS/watchOS27 SDKs reverified before source changes. Every command uses the explicit Xcode developer directory; outputs remain outside source/Drive. Astra Extra High completed a read-only architecture/risk review before this plan and production edits. Bounded implementation uses Astra High, with separate integration/QA.

## Owner-visible outcome

On the Watch, confirm the playing arm and configured wrist/orientation, explicitly start a forehand set, see live recording/data status, pause/resume and stop. Retain original data without the phone. On the iPhone, receive a verified recording, inspect actual retained signals/coverage, enter owner attempt labels, and export a bundle for analysis. Recover interrupted recordings honestly. Retain the existing blue/yellow/white native theme and accessible controls.

This first logger gathers evidence. It does not label contacts automatically, prove that clean hits can be detected, or provide a coaching score. No AI/community/booking work enters this milestone.

## Motion and workout contract

- Watch is the sole capture authority. One recording UUID and one fresh source-clock domain per new set. Never resume an old raw recording after relaunch/reboot.
- Use supported `CMBatchedSensorManager` accelerometer and device-motion streams during an explicit `.other` HealthKit workout. Check support and motion authorization; record reported frequencies separately from measured timestamp rates. Batched rates cannot be configured. No silent lower-rate fallback.
- Request workout sharing access only, with no Health read types. Supply the Health entitlement, workout-processing background mode and accurate motion/Health descriptions. Do not instantiate/save a workout builder/summary. Running a session may nevertheless affect system activity metrics; explain and physically verify this.
- Start streams only after the workout confirms running. Show Starting until both real streams arrive. No fake sensor success in a simulator. Unsupported or unavailable motion yields an explicit compatibility message.
- Preserve each original sensor timestamp and value; do not resample, sort malformed data or substitute callback arrival time. Capture boot-uptime and wall anchors together. Controls and markers use the same boot clock; display relative times while retaining originals in export.
- State model: Ready → Starting → Recording ↔ Pausing/Paused/Resuming → Stopping → Saved; failures → Interrupted/Failed with retained-data information. Repeated commands are guarded.
- Pause establishes a cutoff, stops acquisition, drains admitted samples up to that cutoff, flushes partial chunks, persists the boundary and pauses the workout. Resume waits for a running workout, creates a new segment/generation and restarts streams. Late old-generation callbacks cannot enter the resumed segment.
- Stop establishes a cutoff, stops sources, drains admitted work, flushes partial chunks, verifies/finalizes local storage and ends workout resources even when saving/transfer fails. Only successful durable finalization permits Saved. The batched API has no established final-buffer flush guarantee: terminal-tail coverage remains explicitly unknown.
- On denial, startup failure, stream error, stale input, invalid timing, write error, overflow or unexpected workout termination, stop both sources/resources and preserve successfully published files. Watch active-workout recovery ends stale owned resources and reports interruption; it never automatically resumes capture.

## Bounded engineering defaults for the first physical tester

Initial sets are visibly limited to **120 active capture seconds**, excluding pauses. This is a conservative tester limit, not a proven supported duration or accuracy claim. Flush each stream approximately every two active seconds and at pause/stop. Enforce the existing 256-total-chunk limit directly, reserving terminal chunks; repeated pauses may reach the storage limit earlier and must stop visibly.

Convert framework samples into immutable batches. Admit them through an explicitly bounded sample/byte/batch queue, with one owner serializing capture/storage state. A serial dispatch queue by itself is not a memory bound. Overflow latches an interruption instead of silently dropping samples. No unbounded Task per sample/callback. Use generation fencing and a defined stop drain.

Use monotonic startup/freshness watchdogs (initial five-second engineering windows), driven by the capture owner, not solely SwiftUI timers. Report a missing stream rather than recording indefinitely with no data. Verify these windows physically and revise based on evidence.

Provide canonical trusted Application Support roots, retain descriptor-relative no-follow/exclusive checks for all session descendants, and test actual app-container access. Do not remove storage path checks merely because `/var` aliases caused host fixture failures. Keep heavy file work off the UI executor.

## Files, timeline, labels and transfer interfaces

Container layout: `Recordings/raw/<UUID>/` contains only metadata, manifest and raw chunks. `Recordings/notes/<UUID>/` contains timeline/labels/transfer status. `outbox/` and `inbox/` hold immutable outbound and private staged inbound artifacts.

Shared `RecordingCaptureEventKind` values: start, pauseRequested, paused, resumeRequested, resumed, stopRequested, stopped, interruption, bufferOverflow, writeFailure, limitReached. An event has UUID, kind, original monotonic timestamp and optional bounded detail. `CaptureTimeline` has schema1, recordingID, clockDomainID, events (maximum512) and `terminalTailVerified=false`. Details are limited to128 UTF-8 bytes. Validate monotonic order and identity. Save at transitions outside raw directories.

Owner labels use existing contact categories, stable attempt UUID/ordinal, append-only revision, owner-self provenance, creation time, confidence, evidence source/note and optional clock-matched start/end interval. A label without an established time match remains visibly unmatched/uncertain for analysis; never infer shot timing from its ordinal. Raw files never change when labels change. Export preserves full history.

Shared archive API:

```swift
RecordingArchive.write(recordingID: UUID, rawRoot: URL,
    timeline: CaptureTimeline, destination: URL) throws -> RecordingArchiveReceipt
RecordingArchive.importBundle(from: URL, rawRoot: URL,
    notesRoot: URL) throws -> RecordingArchiveReceipt
```

Receipt identifies recordingID, bundle SHA256, bytes and retained stream coverage. Archive encoding/decoding is streamed with bounded buffers, strict entry allowlists/lengths, per-entry and bundle digests. Receiver stages privately, verifies the archive and `RecordingStore.inspect`, then durably installs raw/timeline outside each other's directories. Identical duplicate receipt succeeds; conflicting content for the same identity fails. Retransmission never overwrites phone label edits. Export adds complete label history.

Use `WCSession.transferFile`, immutable queued outbox files, and durable pending/receipt state. Transport completion does not mean verified receipt. Only a phone-generated application receipt for the expected recordingID+digest produces Verified on Watch. Show queued/transferring/received/verified/failure states distinctly. Offline recording never depends on phone reachability. Watch originals remain until explicit confirmed deletion. No automatic public upload.

Phone review reports retained counts/bounds, bytes, timeline/interruptions, owner-label completeness, declared capability, and observed rate/gap statistics per continuous segment. Pauses do not inflate dropout statistics. Expose the unknown stop tail and unmatched labels. Export/deletion are explicit user actions; deletion states which local copy is affected and that independent exports remain outside app control.

## Bounded implementation packages

Each package has its tests defined before its production edits, at most8 production files, 2,500 changed production lines and2 Level3 domains. Re-split internally if exceeded. Do not treat the whole logger as two domains.

1. **Shared timeline/labels/container paths:** supplied metadata/evidence integrity and annotation persistence. New core files `SessionAnnotations.swift`, `RecordingPaths.swift` and tests. Preserve original practice schemas.
2. **Pure capture engine:** sensor/timestamp semantics and bounded concurrency. New core `MotionCaptureEngine.swift` (and narrowly scoped supporting type file if needed), tests using injected batches/clock/writer faults. Own recording/chunk admission and timeline boundaries.
3. **Watch hardware lifecycle:** sensor acquisition and workout/background lifecycle. `WatchMotionSource.swift`, `WatchWorkoutDriver.swift`, recovery delegate and tests/seams. Consume the engine; no raw classification.
4. **Watch controls/permissions configuration:** explicit lifecycle presentation and permissions. `WatchRecorderModel.swift`, Watch `ContentView.swift`/app entry, Health entitlement and project Info/background settings, supporting tests. Parent owns project configuration; split UI/configuration integration from hardware implementation.
5. **Streaming archive/receipts:** transport format and data-integrity installation. Core `RecordingArchive.swift` and tests. Preserve existing raw bytes and labels on duplicate import.
6. **Connectivity:** device transport and background delivery. Shared `RecordingConnectivity.swift` and tests of receipt/retry/state contracts. Production WCSession remains default; simulator mocks never establish physical delivery.
7. **Phone review/labels:** label state/provenance and annotation persistence through established shared APIs. Phone library/model/views and UI tests. Split export/deletion and final home integration into a separate bounded package if needed.
8. **Integration and physical-test preparation:** rebuild both apps, full affected suites, exact source fingerprint, independent read-only code review (distinct from formal committed-HEAD merge gate), signed-device preflight and concise first-set runbook.

Implementation allocation: Watch/capture agent owns engine/hardware/model/Watch UI. Transfer/core agent owns shared annotations, roots, archive and connectivity APIs. Phone agent owns phone model/review/label/export UI. Parent owns this plan/test contract, project configuration, cross-agent interface agreement, builds, evidence and handover. Shared source interfaces are fixed before dependent integration. Preserve existing uncommitted storage work and historical failures.

## Test contract before code

Capture engine tests: missing/denied start, both-stream readiness, stale stream, source timestamps vs arrival, duplicates/out-of-order data, pause/resume generation fences, cutoff/drain races, bounded overflow, write failure, chunk reserve, time limit and restart prohibition. Assert actual retained sample counts/values and state, not just absence of errors.

Archive/annotation tests: strict schema/identity/time/provenance, append-only labels, malformed/oversized fields, streaming truncation/length/checksum/name/duplicate entry attacks, missing chunks, interrupted recordings, identical retries, conflicting IDs, receipt withholding after failed writes and existing-label preservation.

UI/integration: visible state transitions and errors, fresh arm confirmation each set, disabled unsafe duplicate actions, modern theme/accessibility, session review, label editing, export and confirmed local deletion. Test app-container storage access using the production path provider. Run core regression and relevant iPhone/Watch tests/builds on OS27 without hidden retries; preserve failures/root causes. No fabricated sensor sample mode is exposed as real capture.

Physical acceptance: exact signed build/deviceOS, playing-arm setup, minimal permissions, reported/observed rates, short forehand set, pause/resume, wrist lowered/background, phone disconnection, verified receipt, owner labels and an export with matching IDs/counts. Separately exercise forced interruption/relaunch and workout coexistence. Record actual observations and limits. A successful build is not physical acceptance. Give one device action at a time when owner participation is needed.

## Governance and next action

Owner explicitly authorized the complete tester and planning-before-implementation sequence; scope subdivision is not a reason to stop at another foundation. Record evidence as work proceeds and continue until the usable physical-test build is prepared or an actual external prerequisite requires owner input. Git publication/merge/release policies remain separate; do not merge or claim merge-ready state without the required gates. **Next action: implement the planned packages using Astra, then verify the integrated logger.**

API references checked against the installed27 SDK: [Core Motion WWDC23](https://developer.apple.com/videos/play/wwdc2023/10179/), [workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions), [WatchConnectivity file transfer](https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile(_:metadata:)). Device behavior remains subject to physical evidence.
