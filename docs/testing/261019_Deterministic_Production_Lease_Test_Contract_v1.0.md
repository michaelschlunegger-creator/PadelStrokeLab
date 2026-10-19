# Deterministic production lease regression contract — v1.0

19 October 2026. Branch `feature/watch-recording-storage`, starting committed HEAD `80759910fa356e03c2b61a46a5ae554c19d23978`. This is a separately bounded correction within the owner-authorized complete first-training verification cycle. Astra Extra High performed read-only diagnosis; Astra High implements. No product scope, installation, merge or release approval is added.

## Evidence and diagnosis

Baseline CI run39255888191/job118070941571 completed FAILURE. The lease test at MotionCaptureEngineTests.swift:339 reported three issues: expected Paused, expected competing lease acquisition to throw, and expected Saved. Actual states were printed as `<not evaluated>`; the exact terminal reason was not recorded. Preserve the full log at the private complete-training evidence root, `13-baseline-ci-8075991-job.log`.

The unchanged test uses real uptime and the real dispatch watchdog but supplies only accelerometer data. Its measured CI duration was5.142 seconds, crossing the legitimate five-second missing-stream limit. The uncontrolled wall-clock dependency is a demonstrated fixture defect; watchdog interruption is the strongest explanation, not captured runtime proof. An I/O failure cannot conclusively be excluded. Terminal interruption intentionally seals retained data and releases the lease. No production lease-ownership or clock-domain conversion defect was established. A snapshot is FIFO observation, not recursive queue draining.

## Scope and invariants, defined before edits

Allowed production file: `Packages/PadelCore/Sources/PadelCore/MotionCaptureEngine.swift` only. Add an internal convenience initializer accepting a clock with the existing raw/notes roots and actual production RecordingCaptureLease, RecordingStore, annotations persistence, serial queue and timer. Public initializer delegates with unchanged ProcessInfo.systemUptime default. Do not expose/replace the real writer, change watchdog behavior, increase limits, change queue/lifecycle, permissions, schema, storage or transport. This explicitly amends the training increment's prior no-engine-change boundary for this initialization seam only; one risk domain and one production file.

Allowed test file: `Packages/PadelCore/Tests/PadelCoreTests/MotionCaptureEngineTests.swift` only. No sleeps, retries, skip, suite serialization, weakened assertions or disabled production watchdog. Preserve all prior failed artifacts.

## Required tests

1. Correct the real-writer lease test using CaptureClock and the new internal production-wiring initializer. Supply both streams, establish Recording, assert competing lease exclusion while active and Paused, then Saved and lease release. Preserve durable sample readback, explicitly covering both streams and finalization.
2. Add a regression using the same real writer/store/lease path, deliberately omitting device motion. Before five elapsed seconds assert nonterminal state and lease exclusion. At five seconds drive checkWatchdog and observe through ordered barriers; assert Interrupted, missing-device-motion reason, interrupted finalization, preserved accelerometer sample, lease release, and that Stop cannot change Interrupted to Saved. Use named diagnostic snapshots. Do not infer recursive queue draining.

## Freeze and verification

Freeze source after implementation and generate a new manifest; retain historical manifests. Run focused engine tests, full core suite and affected phone/Watch builds/app regressions under Xcode27 with explicit DEVELOPER_DIR. New production source invalidates earlier build4 artifacts for installation; rebuild/sign and identify final artifacts before any install. Final exact-HEAD CI and separate read-only Astra review remain required. Physical sensor/transfer/export evidence remains open; passing simulations do not establish court readiness.

## Separate CI diagnostic adjustment

Astra Extra High approved15 minutes for the shared-core step after measured cold CI duration588.679 seconds (538.15 seconds compilation), leaving11.321 seconds under the earlier ten-minute bound. Amend the CI diagnostic contract before changing the workflow. Keep the job45-minute limit, exact Swift command/scratch directory, pipefail/tee and unconditional evidence upload. No retries or continue-on-error. Artifact retention for the failing baseline succeeded: artifact12188571201, `foundation-39255888191-1`, SHA256 `b92fafa396f9daee6340160dd79fd04ffab3c62fe1d523c5d6aec148677d9bcf`.
