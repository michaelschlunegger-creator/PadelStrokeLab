# Logger independent-review corrections — v1.0

19 October2026, Asia/Dubai. Defined before source changes. Owner authorization covers the complete physical tester, Astra implementation and the approved publication/review cycle. These corrections preserve that scope; no new product feature, permission, measurement claim, platform or architecture is introduced.

## Starting evidence and scope

Committed/pushed HEAD `8379aaa7ddebcd8528e41916a65c052718e21eb7`, branch `feature/watch-recording-storage`, base `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, draft PR2. New independent Astra Extra High read-only review found a real Watch settings-recovery dead end and an unbounded crash-helper test process. CI run39245546273 remains in progress in its shared-core step; active-log reads returnedHTTP502. Neither observation proves the test wait caused that delay. Preserve the run and every failed result; do not call the old source clean or installed. Historical manifests/evidence remain unchanged.

Implementation uses Astra High in two separate bounded packages. Parent owns build identity, manifests, integration checks and publication. Independent reviewer does not edit. No source/main merge or release.

## Package R1 — refresh Watch preparation after Settings

Allowed source: `PadelStrokeLab Watch App/WatchRecorderModel.swift`, `PadelStrokeLab Watch App/ContentView.swift`; tests: existing Watch app unit test file. Two production files, permissions/setup and lifecycle-state risks, no sensor/clock/storage/transport implementation changes.

Observed trigger: model caches Motion authorization and Watch wrist/crown at launch. `canStart` disables the button from those cached values, while `start` refreshes them only after a tap. Granting Motion access or correcting the configured wrist in Settings and returning to the same surviving model therefore cannot enable Start. No scene-activation refresh exists. A relaunch is a workaround, not the intended recovery path.

Required behavior: refresh actual capability/wrist/crown/frequency on foreground activation when preparation is allowed (Ready or terminal). Initialization/new-set and the Start action retain fresh checks. If wrist/crown configuration changes, clear playing-arm confirmation so metadata cannot rely on the previous configuration. Preserve storage errors and the real simulator/unsupported-device reason. Do not auto-authorize, auto-start capture/workouts, change active/paused capture metadata or alter raw data. Ignore preparation refresh while capture is starting/recording/pausing/paused/resuming/stopping.

Tests before implementation: a deterministic production-default-preserving settings provider/seam exercises the real model refresh. Cover denied→granted without recreating model; mismatch→correct wrist without recreating model; crown/wrist changes clear confirmation; unchanged configuration preserves the appropriate idle state; active phases are excluded; simulator/default source remains honest and denied/restricted remains disabled. No UI launch option exposes fake supported hardware. Preserve existing regressions. No extra permission or entitlement.

## Package R2 — bound crash-recovery test subprocesses

Allowed: `Packages/PadelCore/Tests/PadelCoreTests/RecordingStoreTests.swift`, with a narrowly scoped new test-helper file only if required for clarity. No production PadelCore/app source change. Risk is test liveness only.

Confirmed defect: `abruptProcessExitPreservesTruthfulRecovery` redirects stdout/stderr into a Pipe, calls unbounded `waitUntilExit`, then drains the pipe. A stalled child or filled pipe can hang the suite indefinitely. This is an actual harness defect independent of whether it caused current hosted CI symptoms.

Required behavior: impose a finite deadline; continuously drain output or use an owned temporary file so child output cannot block on an unread pipe; retain bounded useful diagnostics; terminate/reap only the child launched by this helper on timeout, with bounded cleanup. No killall/pkill, global process state or personal files. Prevent recursive parent crash-test invocation if child selection is not honored, failing explicitly rather than spawning another generation. Preserve the actual SwiftPM runner arguments/bundle selection and four intended abrupt boundaries.

Tests before implementation: a normal owned subprocess completes with preserved status/output; an output volume larger than a pipe buffer completes and yields useful bounded diagnostics; a deliberately stalled owned subprocess times out promptly and is cleaned up. Every original expected exit71/72/73/74, retained-byte comparison, finalization and recovery assertion remains unchanged. Do not skip tests or mask an unexpected child status. Report the actual resulting core test total. Preserve any initial failure and correct the real cause only.

## Integration and evidence

Parent increments both app build numbers from2 to3 and the existing test-bundle build numbers from1 to3 in `PadelStrokeLab.xcodeproj/project.pbxproj` (12 existing configuration values total); bundle/team/signing/OS/companion settings stay unchanged. This distinguishes the corrected physical tester and its test bundles from earlier build2 artifacts. Parent defines a new manifest before final verification and updates only the workflow's manifest reference. Preserve every prior manifest and log; do not rerun or relabel the old CI result as success.

After frozen source: full core regression; both Release simulator builds; complete affected Watch unit/UI suite and iPhone regression as appropriate to project/build identity; generic signed physical build3 and signature/profile checks. Keep generated files/results outside source. New source invalidates affected old evidence. Record exact commands, results, failures and per-file carry-forward limits. Reconcile scoped diff, commit/push under the approved PR publication cycle, verify exact remote HEAD, obtain new exact-HEAD hosted CI and independent read-only review. No physical installation before required gates, and no merge-ready claim before physical G7.
