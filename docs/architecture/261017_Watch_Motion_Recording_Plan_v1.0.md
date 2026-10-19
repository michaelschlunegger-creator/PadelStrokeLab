# Watch motion recording — proposed implementation plan

17 October 2026. Status: **APPROVED for package A** by the owner's response “ok, add the code” to the plan/branch approval request. Later packages remain separately scoped.

## Purpose and authority

Owner request: implement Watch motion recording after the preparation UI walkthrough. Authority: PSL-SPEC-001 v1.1, sections 6–7, 18–23; S1-01–04/S1-08 and T01–03/T15–16. This is part of WP1, not all of WP1. No automatic contact-quality judgment is included.

The intended result is a user-started, Watch-owned recording on the playing arm, preserved locally through ordinary failures and available for subsequent verified retrieval. Phone transfer, labels tied to attempts and export remain separately scoped work before court collection is declared ready. No paid coach, account, cloud upload or Apple Intelligence is needed for capture.

## G0 — verified starting point

- Checkout: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`.
- Branch/upstream: `chore/project-governance` / `origin/chore/project-governance`; both at `ee15c0ef86c99064bb1295c7550fba1daea66a3c`. Worktree was clean before these planning edits.
- Live remote and local remote-tracking main: `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. Feature branch is six commits ahead, zero behind. No local `main` branch exists; a read attempting to resolve it failed and changed nothing.
- Draft PR #1 is open/unmerged. Exact-head hosted run 39031993296 is **CANCELLED**, not a CI pass. Existing foundation merge gates remain open.
- Xcode 27.0 (27A266a), iOS/watchOS 27.0 SDKs reverified. Commands retain the explicit Xcode developer directory; global selection is unchanged.
- Owner completed a simulator walkthrough of phone preparation/navigation and Watch arm selection/confirmation/reset. These are reported UI observations, not motion, physical-device, accessibility or battery acceptance. The earlier Mac-lock blocker is superseded by the completed walkthrough.

## Approved decisions

1. Approve this staged architecture and the storage-only first package/test contract below. Later live-capture packages must have their own bounded contracts before code; this approval does not waive any gate.
2. Approve a local dependent branch `feature/watch-recording-storage` starting at verified `ee15c0e`. This is an explicit exception to the normal clean-main branch rule because main does not yet contain the app. It does not merge the foundation or make its unresolved gates pass. Rebase/merge later requires affected verification again.
3. Adopt the intended supported capture route: an explicit active HealthKit workout, runtime-checked high-rate Core Motion support, and no silent lower-rate fallback. Proposed workout activity is `.other` with padel/forehand drill metadata; `.paddleSports` is canoeing/kayaking, not padel. The app will not create a saved workout summary in this prototype; watchOS may still record activity/health metrics. Permission/background configuration and this behavior must be verified before live capture.

No commit, push, new PR, merge, physical install, release, expense or public data upload is performed by this planning task.

## Delivery sequence and risk boundaries

### A — durable recording foundation: implement first

Two Level 3 domains: raw timestamp/evidence validation and durable storage/recovery. This is synchronous local-file work only. No active-session controller, background execution, async ingestion, live sensor or workout resource owner is included.

Allowed production files, all new in `Packages/PadelCore/Sources/PadelCore/`:

- `RecordingModels.swift`: immutable versioned recording/chunk metadata and timestamp/evidence validation.
- `RecordingChunkCodec.swift`: bounded raw-stream encoding and decoding.
- `RecordingStore.swift`: bounded synchronous local writes, no-overwrite identity/sequence rules and truthful finalization.

`RecordingStore` also provides non-destructive inspection/recovery. Its initial contract is synchronous and single-caller; concurrency ownership is deferred, not implicitly considered safe.

Supporting changes: package tests and relevant documentation only. No existing practice schema migration or modification of raw recordings. Maximum eight production files, 2,500 changed production lines and two Level 3 domains remains binding. Split further if needed.

Data contract: stable recording ID; explicit schema/stream/units/coordinate convention; app/protocol/capability and setup metadata; boot-relative sample timestamps with a separate wall-clock anchor and clock-domain identity; independent per-stream chunk sequences; sample counts and bounds; checksums; declared retained coverage and completion status. Store source timestamps without resampling or replacing them with callback arrival time. Reject nonfinite, malformed, unsupported, conflicting, oversized and out-of-order input. Do not infer a clean hit from any raw field.

Proposed maximum encoded chunk size: **1 MiB**. Reject an oversized chunk before commit and oversized file input before decoding. Bound memory and sample counts before allocation; freeze further codec/inspection limits as engineering constants in the test contract before production edits, with no promise about sensor rate or session duration. Storage uses exclusively created session directories, atomic publication of fully written chunks and explicit synchronization/error checking; verify checksums/counts before reporting a finalized archive. Do not claim survival of every hardware/power failure merely because an API returned success.

Recovery preserves source evidence, recognizes partial/unfinalized sessions, and never upgrades a recovered session to uninterrupted completion. Corrupt/unknown files are reported and retained, not silently discarded. A storage error must not yield a successful saved result. This package cannot start capture and does not yet expose a recording button.

### B — sensor acquisition and timing

Next bounded contract: public Core Motion adapter, actual capability/rate reports, immutable batch conversion, source clock mapping, stream validation and observed gaps. Test real production adapters through hardware seams with production defaults intact. No fabricated simulator motion and no unlabelled fallback. The resulting adapter alone is not a court-ready recorder.

### C — workout/lifecycle and integration

Separately scope minimal HealthKit authorization/entitlements/background mode, single resource owner, bounded concurrency, controller and native blue/yellow/white Watch controls. Split this package again if the domain/file/line budget is exceeded. Permissions, lifecycle, concurrency and sensor authority must not be hidden under a single generic risk label.

Visible states: ready, starting, recording, paused, stopping, locally saved, interrupted and failed. Fresh playing-arm confirmation for every new session; lock setup during recording. Only explicit Start initiates capture. Pause/resume creates explicit segments, not a fabricated continuous timeline. Stop is idempotent. Keep phone independence; no phone connection is needed to retain local data.

Do not present Recording until workout/capture prerequisites and actual incoming signals establish it. Stop acquisition and owned workout resources on every exit/error. Fence late callbacks by session/generation and prevent unbounded pending work. Fail closed on denial, unsupported capability, startup timeout, other-workout conflict, stream failure or write/backpressure failure. Preserve recoverable chunks. Never automatically restart after relaunch/reboot; do not combine different boot clocks.

Apple's batched API has no documented final-buffer flush guarantee. Record the stop request and each stream's last retained sample separately; expose any unobserved terminal interval. “Locally saved” describes retained validated data, not a claim of complete capture through the button press. Wrist lowering/background continuity, authorization, conflicting workouts, system activity effects, rates and battery require physical evidence.

### D — verified retrieval and first court protocol

Separate transfer/export/review contracts establish verified copies, owner labels and usable retrieval before court collection is accepted. Source deletion must never depend on an unverified transfer. No quality score, AI summary, social feature or ranking is part of these capture packages.

## Verification and gates

See the companion [test contract](../testing/261017_Watch_Recording_Test_Contract_v1.0.md). Define tests before production changes. Preserve failures; no automatic retry. Build/test with OS 27 only. Review exact committed source independently; clean CI and relevant physical evidence remain required before merge readiness. An owner-approved merge is still separate.

Do not promote the specification's proposed 90-minute duration, 10-second checkpoint or battery budgets to proven capabilities. Measure actual retained coverage, bytes/minute, loss windows and battery on physical hardware before accepting a court protocol.

## Apple API evidence checked

- [What's new in Core Motion, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10179/): high-rate batched streams require an active HealthKit workout; check support; published rates are capabilities, not this app's measured results.
- [Running workout sessions](https://developer.apple.com/documentation/healthkit/running-workout-sessions): workout authorization, background mode, system collection and resource lifecycle.
- Installed watchOS 27 SDK headers: `CMBatchedSensorManager.h`, `HKWorkoutActivityType.h`, `HKWorkoutSession.h`, `HKDefines.h`. No public flush method is declared in the batched manager header. Runtime and physical behavior remain unverified.

Architecture review: **Astra Extra High**, review only, completed without file changes or new test execution. The reviewer recommends storage-only implementation first and explicitly rejects treating the entire live recorder as two risk domains. See the [review record](../reviews/261017_Watch_Recording_Architecture_Review_v1.0.md). Owner approved package A and the dependent local branch on 17 October 2026. No merge, physical installation or remote publication is authorized by that decision.
