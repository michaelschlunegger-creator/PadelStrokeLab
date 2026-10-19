# Complete-training local verification — v1.0

## Latest source and collection checkpoint

Current [55-file screen-capture manifest](261019_Complete_Training_Screen_Capture_Code_State.sha256), SHA256 `ea180bdee7036dd996fda592301f773b31e28e2e5779adda279f890a6f19d295`, supersedes the older current-manifest/hold statements below. Only two phone UI screenshot collectors and the workflow reference differ from6b4b2c82;52 source entries, including all production/core/Watch/build configuration, remain identical. Mac-open/unlocked and physical connection confirmations have arrived; both iPhone/Watch development tunnels and DDI were reached. No installation occurred.

`30-phone-paired-landscape.log/.xcresult`: PASS focused XL landscape guide test,96.934 seconds, exit0. `30-phone-attachments/` retains paired application/full-screen PNGs and geometry. [Independent Astra Extra High diagnosis](../reviews/261019_Landscape_Capture_Review_v1.0.md) confirms the app screenshot collector crops/pads while full-screen rendering is complete: application/window852×393, application image392.667×852, full-screen852×392.667. Parent also inspected home/practice/contact-lower full-screen images. Use full-screen attachments for visual acceptance; malformed application images remain diagnostic evidence. No production layout change was made.

`31-phone-all-ui-screen-evidence.log/.xcresult`: PASS all9 final phone UI executions,552.289 seconds, exit0, with300-second per-test bound. `31-phone-attachments/` retains paired captures/geometry. Parent inspected full-screen normal portrait home and landscape launch, alongside run30's full-screen XL landscape home/practice/contact captures and run26 portrait XL. The collector anomaly is resolved for visual assessment without a production layout change. Core108,23 Watch/8 phone app-host,8 Watch UI, both Release builds and signed build4/signature results carry by unchanged per-file identity. Thus every app-host/UI target is covered at the final runtime source; focused repetitions are not counted as unique tests. Exact-HEAD CI/new independent committed-source review and all physical workflows remain open. No test/build remains running.

Unaltered synthetic UI screenshots copied for persistent GitHub review: [Watch setup](screenshots/261019_Complete_Training/Watch_Setup_Build4.png), SHA256 `ea32b4a9f2eb7ceb01fca5a475187e6e7a082a0e8f99c682d0a7ecced762ff70`, from run24 `5165CE01-9E21-41E7-8EE6-24A5267CAAE9.png`; [XL landscape practice guide](screenshots/261019_Complete_Training/Phone_Landscape_AX5_Build4.png), SHA256 `ca56b9a1ee28721b2c556e29c551df052f35563af972d93b53631e5162851b7a`, from run30 full-screen `0E8C1662-D97C-45AE-8175-30BFFFBF2B68.png`. No physical recordings or private device identifiers are included.

[Normal portrait home](screenshots/261019_Complete_Training/Phone_Home_Build4.png), SHA256 `87814490aee5aa4ecf3eedad0c163229b78b74979e84131d285e4caadc09e5e9`, is an unaltered run31 full-screen copy of `95925D19-169D-40B1-ABF4-E550870930BA.png`.

## Current frozen correction and results — 19 October2026

Owner subsequently confirmed the Mac lid is open and Mac unlocked, resolving the UI-test hold below. Frozen-source runs23–26 use command-scoped caffeinate; no source changed between app-host and UI invocations. Focused runs are diagnostic confirmation, not additional unique coverage in suite totals.

- `23-watch-recovery-focused.log/.xcresult`: PASS1 previously failing invalid-preference/relaunch recovery UI test,26.058 seconds, exit0.
- `24-watch-all-ui.log/.xcresult`: PASS all8 Watch UI executions,201.474 seconds, exit0. Combined with run21's23 app-host tests, this covers both complete Watch scheme test targets at the same frozen source. Exported screenshot evidence retained in `24-watch-attachments/`; screenshots show the blue/yellow/white setup and truthful simulator capability/disabled recording controls. Native test export mislabels the paired device name as iPhone; device ID91757361 and Watch pixels identify the actual Watch destination.
- `25-phone-guide-focused.log/.xcresult`: PASS1 previously sleep-interrupted guide/navigation test,31.128 seconds, exit0, unchanged phone source. This invocation explicitly enables/defaults/caps per-test timeout at300 seconds; no automatic retry.
- `26-phone-all-ui.log/.xcresult`: PASS all9 phone UI executions,344.296 seconds, exit0, with the same300-second per-test bound. Combined with run22's8 app-host tests, this covers both complete phone scheme test targets at the frozen source. Portrait and landscape AX5/navigation assertions passed. Exported `26-phone-attachments/` revealed malformed application-cropped landscape screenshots, so this automated pass does not close the visual-evidence gate.
- `27-preinstall-device-inventory.json`: both previously paired physical devices are now development-tunnel disconnected, with DDI services unavailable; iPhone15Pro/iOS27.2 and WatchUltra2/watchOS27.0.1. Simulators are connected separately. Private raw identifiers remain outside Git. Owner has been asked to connect/unlock the iPhone while verification continues. This inventory does not establish a current device connection or installation.
- Owner confirmed the iPhone connected/unlocked. `28-connected-device-inventory.json` confirms iPhone wired development tunnel connected/DDI available. Bounded read-only Watch details probe `29-watch-connection-probe.json` subsequently succeeded exit0 and established Watch network tunnel connected/DDI available. No installation or launch occurred. Recheck availability when pre-install gates clear.

### Landscape screenshot evidence gap and pre-edit correction

Parent inspected passing run26's exported landscape guide PNG: visible black padding/clipped content. Astra Extra High's read-only pixel/metadata diagnosis found2556×1178 raster but nonblack pixels only in x0…1178,y0…1177, with1377 zero-RGB columns. This appears across all four XL landscape captures and both ordinary-text landscape launch captures; EXIF8/6 explains the rotated presentation, but the black pixels are present in the original data. Portrait reference is1178×2556/orientation1 without whole black columns. The original example SHA256 is `c1a90f7d06fe141147484dfd6d641c1c23c7947beb95bfabed5092228ba9e70e`. Metadata-only diagnostic derivatives preserve IDAT and remain private; originals unchanged.

Both collectors use app.screenshot; source supports landscape. The repeated short-edge-square crop strongly supports an application-screenshot capture artifact, but actual landscape screen rendering remains unobserved. No production UI fix is justified. [Paired-capture diagnostic contract](261019_Landscape_Screenshot_Diagnostic_Contract_v1.0.md) was recorded before Astra High's bounded two-file phone UI-test instrumentation. Preserve existing captures/assertions, add full-screen captures/geometry, freeze new manifest, then one focused landscape test. Publication stays on hold until actual visual evidence resolves the gap. App/core/Watch/build source remains frozen and earlier evidence carries only by identical per-file hashes.

The [55-file deterministic-lease manifest](261019_Complete_Training_Deterministic_Lease_Code_State.sha256), SHA256 `6b4b2c82618e5ac5e979a663b9e47f54650ed602c105bc8a8491f6d824a54dd0`, supersedes earlier current-manifest statements. Relative to537b0245, only the generic Watch navigation fixture, engine initialization seam, engine regression tests and workflow diagnostics/manifest reference changed. Historical manifests remain intact. Astra High authored both bounded corrections; [Astra Extra High read-only correction review](../reviews/261019_Deterministic_Lease_Correction_Review_v1.0.md) found no code defects or contract blockers. That review is not final committed-HEAD review.

New artifacts in the same private `complete-training` evidence root:

- `14-engine-deterministic.log`: invocation failure exit127 before any test; parent used a nonexistent Xcode-local xcrun path. Corrected to `/usr/bin/xcrun` with explicit DEVELOPER_DIR in a new command/artifact; no source change. Preserve this failure.
- `15-engine-deterministic.log`: PASS20 motion-engine tests,1 suite,0.303-second test phase, exit0. Includes both deterministic real-production-writer lease tests.
- `16-full-core-deterministic.log`: PASS108 tests,10 suites,2.261-second test phase, exit0. No retry or skip.
- `17-phone-release-deterministic.log`: PASS iPhone Release build, iPhone15Pro/iOS27 simulator2CE85F58-306B-49ED-8AC2-CA9D78A45F2A.
- `18-watch-release-deterministic.log`: PASS Watch Release build, Ultra2/watchOS27 simulator91757361-AEA2-41D8-9C4F-6DE5FF6365DA.
- `19-device-build4-deterministic.log`: PASS signed Debug generic iOS build with embedded Watch. No install/launch occurred.
- `20-build4-deterministic-signature-identity.json`: both separate deep/strict signature verifications PASS; version1.0/build4, min27.0, SDK27.0; Watch companion/workout-processing preserved. Actual iPhone executable SHA256 `a4852c302b205a7fabb970cd0c35b7c424578e3a28006585034b16c1fce705a6`, Watch `7f86f23558ac9c220a45676d3baa5a9ac23b9cc6ef0ad0b7a39841356fd5ee4c`. These replace earlier build4 executable identities for the changed engine.

- `21-watch-app-host-deterministic.log/.xcresult`: PASS23 Watch app-host tests,1 suite,0.156-second test phase, exit0; UI target not executed.
- `22-phone-app-host-deterministic.log/.xcresult`: PASS8 phone app-host tests,2 suites,0.270-second test phase, exit0; UI target not executed.
- Workflow YAML parses. Structural comparison against8075991 confirms exactly the new source-manifest reference and15-minute core-step bound differ; job45-minute bound, test/build commands, failure behavior and unconditional upload are unchanged. Final whitespace check passes.

Every Swift/Xcode command explicitly selects `/Applications/Xcode.app/Contents/Developer` (verified Xcode27.0/27A266a). Command-scoped caffeinate prevents idle/display sleep but cannot prevent lid-close sleep. No UI test has been launched since the pending owner confirmation request. Current complete app-host regressions pass; full UI verification, exact-HEAD publication/CI/review and all physical observations remain open. No test/build remains running at this checkpoint. Resume the bounded focused Watch recovery and unchanged-source phone flow, then remaining UI suites under the same frozen source only after owner Mac-open/unlocked confirmation. Preserve all prior failures.

19 October2026, Asia/Dubai. Working branch `feature/watch-recording-storage`, starting committed/pushed HEAD `80759910fa356e03c2b61a46a5ae554c19d23978`, base/foundation `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; draft PR2 remains open/unmerged. This package is owner-approved under the full-training/shot-type amendment. Astra Extra High reviewed [planv1.1](../architecture/261019_Broader_Training_Readiness_Plan_v1.1.md) and the [test contract](261019_Complete_Training_Test_Contract_v1.0.md) before Astra High implementation. Parent owns integration checks. No merge/release or physical installation occurred.

## Frozen source

Five production files197 changed lines and five test files361 changed lines implement the bounded expansion; no helper or scope exception. Parent changes exactly12 project build settings3->4, workflow manifest reference and an Astra-reviewed10-minute shared-core diagnostic timeout. No historical schema/capture/store/transport/permission/signing/OS/bundle change. [55-file manifest](261019_Complete_Training_Code_State.sha256), SHA256 `46a99c053faac1e95d8fad3b7ea807703ca3aaeba52e3be8c789bd1f4be6fb32`, was frozen before final verification and rechecked after builds. Old manifests remain unchanged.

Core defaults and real adapters remain honest. New ten-choice manual vocabulary uses `owner-manual-training-logger-1`; Start snapshots immutable metadata before asynchronous work, editing is Ready-only, active/terminal intent is retained, and New set clears capture/confirmation. Missing/invalid stored choice blocks Start without coercion. Existing and unknown raw metadata remain readable and unmodified. Phone guidance/details/review/export expose intended type separately from owner contact labels. No automatic classifier or quality score.

## Toolchain, commands and artifacts

All commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; Xcode27.0(27A266a), Swift6.4 and OS27 SDKs verified before edits. Dedicated connected paired simulators: phone `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A` (iPhone15Pro/iOS27), Watch `91757361-AEA2-41D8-9C4F-6DE5FF6365DA` (Ultra2/watchOS27). No automatic retries enabled. Frozen source was not mutated during tests/builds.

Artifacts root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-LiveLogger/complete-training/`. Xcode simulator derived data: parent `PadelStrokeLab-LiveLogger`; physical derived data: `PadelStrokeLab-LiveLogger-Physical`. Both are outside source/Drive.

| Artifact | Actual result |
|---|---|
| `01-full-core.log` | PASS exit0;107 Swift Testing tests in10 suites, test phase2.259seconds. Includes all ten synthetic both-stream store/archive/import roundtrips. Synthetic data is not sensor evidence. |
| `02-phone-release.log` | PASS exit0; iPhone Release simulator build. |
| `03-device-build4.log` | PASS exit0; signed generic physical iPhone Debug build including embedded Watch app. |
| `04-watch-release.log` | PASS exit0; Watch Release simulator build. |
| `05-build4-signature-identity.json` | PASS; both actual products version1.0/build4, OS27 minima/SDKs, deep/strict signatures verified. Companion identifier matches, Watch workout-processing background mode retained. |
| `06-watch-full.log` / `.xcresult` | FAIL exit65 at test compilation; phone companion RecordingLibraryTests155 uses a throwing loadTimeline call inside #require without an inner try. No full Watch/UI-suite result follows. |
| `07-source-verification.log` | PASS; all55 source/config/test/workflow entries match. |

Core command: `xcrun swift test --package-path Packages/PadelCore --scratch-path /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-LiveLogger/complete-training/core`.

Release commands use `xcodebuild -project PadelStrokeLab.xcodeproj`, corresponding phone/Watch scheme, Release, corresponding dedicated simulator destination, simulator derived-data path, `CODE_SIGNING_ALLOWED=NO build`. Physical command uses phone scheme, Debug, `generic/platform=iOS`, physical derived-data path and `-allowProvisioningUpdates build`. It does not install apps. Signature checks call `codesign --verify --deep --strict` on the built phone and embedded Watch products separately.

Watch command uses Debug, dedicated Watch simulator, `-only-testing:PadelStrokeLab Watch AppTests`, `-only-testing:PadelStrokeLab Watch AppUITests`, `-parallel-testing-enabled NO`, signing disabled and unique result bundle. Full phone regression remains pending. Parent inspects new picker/phone screenshots after tests; populated real-session detail visual acceptance remains physical work rather than a fake UI recording mode.

## Hosted baseline and diagnostic limits

Historical run39245546273 was cancelled at45-minute job limit. Baseline8075991 run39255888191 remained in progress with shared metadata active in a fresh GitHub page observation about16minutes after creation. Job-log backendHTTP502, connector404 BlobNotFound and absent old artifacts prevent a demonstrated root cause. These are unavailable-log observations, not a test diagnosis. The reviewed [CI diagnostic contract](261019_CI_Core_Diagnostic_Contract_v1.0.md) adds only a10-minute limit to the future shared test step, keeping the exact suite/pipefail/tee and always-artifact upload. A timeout is failed/incomplete evidence; it cannot be called a pass. Verify actual artifact retention and inspect logs before another change. This does not affect an already running baseline job.

New source/configuration requires its own exact-HEAD hosted CI and independent committed-code review after publication. Baseline [Astra review8075991](../reviews/261019_Committed_Logger_Review_8075991_v1.0.md) resolved old code blockers but is BLOCKED on CI/physical/old forehand-only scope; it is not a verdict on this expansion.

## Physical readiness and limits

No physical installation/launch/permission/motion/background/transfer/export/battery/court observation yet. Signed builds and simulator passes cannot prove those behaviors. Complete the pre-install gates, then follow the [complete-training runbook](261019_Complete_Training_Physical_Runbook_v1.0.md) one action at a time, beginning with a non-forehand-selected air swing, verified phone receipt and read-back export. Confirm type/protocol/counts and raw/label preservation before contacts. The owner supplies self labels; no paid coach or independent ground-truth claim. Merge/release remain unauthorized.


## Preserved first app-suite failure and bounded correction

Run06 failed while compiling the phone companion test dependency, not from a proven recording/UI runtime defect. At RecordingLibraryTests155, `try #require(SessionAnnotationsStore(...).loadTimeline(...))` expands into a throwing call without the required inner `try`. Compiler diagnostics and result bundle are retained. Before editing, the scoped correction allows only `PadelStrokeLabTests/RecordingLibraryTests.swift`: evaluate the throwing timeline load separately, then require the optional result, preserving the assertion and all values. No production, other tests or build configuration change. Astra High performs the correction and freezes source again before parent verification. The initial55-file manifest46a99c... remains unchanged; use a new manifest/workflow reference for the corrected test source. Core/production/build bytes are unchanged and their earlier passing evidence can carry forward only by per-file identity. No retries or weakened assertions.


## Current compile-corrected source

Astra High changed only the throwing-call evaluation in RecordingLibraryTests; assertions/fixture values unchanged. The parent verified all other54 entries matched the initial manifest before updating the workflow reference. Current [55-file compile-fix manifest](261019_Complete_Training_Test_Compile_Fix_Code_State.sha256), SHA256 `5b32ead9b5020fc86ffe1c262c93a54c00ed33dd9414c7346d65f274c1754061`, differs only in that test file and workflow reference. All53 remaining entries, including all production/core/configuration, are byte-identical. Core107, both Release builds and signed build4/signatures therefore retain their exact tested production identity; app-host/UI evidence still needs the corrected source.

`08-watch-compile-fixed.log` and unique `.xcresult` are running under the same full affected Watch command; no current suite pass claimed. The earlier run06 stays failed. No source mutation during this run. All55 entries will be reverified before publication. No installation/merge/release.


## Watch UI navigation failures observed in run08

Watch app-host logic passed23 tests in1 suite (0.142seconds). The full UI run remains in progress and already has failed assertions; it is not a passing suite. The original arm flow fails at Watch AppUITests30 because it requires a virtualized offscreen arm picker to exist before calling its bounded reveal helper. The larger training header and new shot row place it below the initial viewport; `08-watch-live-diagnostic.png` retains a current top-of-screen diagnostic. The handedness flow successfully scrolls and passes, supporting the observed test-navigation diagnosis rather than proving a runtime recording defect.

The intended-shot flow fails at helper218: `app.collectionViews.element.swipeDown` is ambiguous when the native picker leaves both main and picker collections in the accessibility hierarchy. This is an observed query failure, not an inferred sensor problem. Preserve log/result attachments; inspect final outcome before editing.

Bounded UI-fixture correction contract before changes: only `PadelStrokeLab Watch AppUITests/PadelStrokeLab_Watch_AppUITests.swift` may change. Reveal virtualized controls before requiring their existence/values, and use the actual foreground picker/list gesture or an unambiguous observed container rather than arbitrary firstMatch. Preserve24-attempt bounds, full visibility/hittability requirements for controls, text assertions, persistence, confirmation/reset, invalid preference, Other and real-simulator-block checks. No production/UI-layout/metadata/unit/core test change or assertion relaxation. Astra High will implement only after run08 completes, freeze source and report hashes; parent then generates a new manifest and reruns affected flows/full suite with unique artifacts. Identical production/core/build evidence carries only by per-file hashes; failed runs06/08 remain failed.


## Run08 final outcome and evidence-based UI fixture correction

Run08 ended FAIL exit65:23 app-host tests passed;8 UI executions contained3 failures (arm initial existence, intended-shot picker normalization, unknown-choice issue reveal). Handedness/simulator/performance and both launch configurations passed. Optional extra simulator-diagnostic collection also failed to resolve simctl after the assertion failures; explicit test developer directory/SDK27 remain verified. That diagnostic failure did not cause the assertions. Exported attachments are retained in08-watch-attachments.

Astra High inspected preserved video frames. The invalid preference DID apply: the header visibly says Saved shot type unavailable—choose again. Repeated50pt test drags move then snap back to the unusually tall carousel card. Read-only extracted frames5/10/20/30 support this; no preference/model defect was established. Picker normalization also required viewport.contains(full button frame), impossible for native width201/x2 versus inset viewport width193/x6. The corrected anchor uses the already required midpoint/90%-visible-height rule. Foreground app gestures remove the ambiguous two-collection query. Virtualized controls are revealed before existence/value checks. The invalid case first asserts the visible warning header, then performs one deliberate longer foreground swipe before unchanged error-row/recovery assertions. Existing24-attempt bounds, control hittability, text/persistence/reset/Other/simulator checks are intact. Only the Watch UI test file changed.

Current [55-file Watch-navigation manifest](261019_Complete_Training_Watch_UI_Code_State.sha256), SHA256 `c2e3a923e9af340e7037766a512dc185a7b9326ddb57274b702c4bda40d068c9`, differs from5b32ead9 only in Watch UI tests and workflow manifest reference; all53 other files remain byte-identical. Original manifests46a99c and5b32ead9/logs06/08 remain unchanged failed evidence. Core107,23 Watch app-host and production/Release/signed-build4 evidence retain per-file validity; full current suite is still required. Run09-watch-navigation-fixed full affected suite is running with unique log/result bundle and no source mutation. Full phone regression remains pending.


## Run09 final result and phone regression

Run09 finished FAIL exit65:23 Watch app-host tests passed;8 UI executions with one remaining failure, unknown-choice error-row reveal. The original arm flow, new handedness flow, native shot selection/persistence/Other flow, simulator block, launch performance and two launch configurations all passed. Header warning assertion now passes, confirming invalid preference handling; the subsequent watchShotSelectionIssue row still cannot be revealed within24attempts after the deliberate native swipe. No next fixture change is authorized until this exact failure's video/frames are diagnosed. Artifacts09-watch-attachments, log and result bundle retained; optional extra simctl diagnostic failure is again secondary to the UI assertion. Run09 remains failed, not a pass.

With source still frozen atc2e3a923, full phone Debug regression10-phone-full is running using the dedicated phone simulator, no parallel tests, signing disabled and a unique result bundle. Astra may inspect retained Watch failure read-only while this runs, but must not mutate source before the parent confirms all current tests ended. Phone result is pending. No installation/merge/release.


## Read-only diagnosis of the remaining run09 failure

Astra inspected actual video frames at4.1/4.2seconds: the invalid-choice error row is visibly intact beneath the closed picker (Choose shot type), with the original warning text. This rules out silent selection coercion in the observed sequence. By5.6seconds the native swipe has carried the row above the viewport to placement/Capture; the first reveal check at6.44seconds sees an absent virtualized row and subsequent forward scans move farther away. Parent also inspected the4.1second frame. No production defect is evidenced by this failure.

Astra's minimal proposal, recorded BEFORE editing: replace only the single deliberate native swipe in the unknown-preference UI test with a bounded low-inertia coordinate drag (roughly normalized0.85->0.35, slow, held endpoint) to leave the tall header without fling overshoot. Keep header/error/recovery assertions and24-attempt full visibility/hittability checks. Same single Watch UI test file allowed; no production/other tests/config change by the author. Source must remain frozen until the parent confirms phone run10 ended. Preserve run09 as failed and use a new current manifest/result bundle after correction. The independent reviewer must inspect that no assertions were weakened.


## Phone10 / Watch11 final evidence and next bounded corrections

Phone10 FAIL65:8 app-host tests passed,9UIexecutions with one failure in practice-guide navigation. Largest-text flows and other UI checks passed. Test helper127 timed out synthesizing a drag; the entire UI suite took1724.753seconds. Astra Extra High correlated exact pmset history: clamshell sleep17:46:02 for281seconds, dark wake17:50:43; failing drag17:46:04.242 -> timeout17:50:43.692. Earlier90second startup and504second delayed teardown likewise match sleep intervals. A retained spindump shows idle main-thread mach_msg, not an evidenced app busy loop. Root cause of this observed event-delivery timeout is system sleep. No production/test-gesture correction is justified. Preserve failed result and filtered power evidence; owner was asked to keep Mac lid open/unlocked before a controlled repeat. No further UI test starts until that response.

Current controlled-Watch manifest537b02450051b1a7d7fbcb47bf4b9962ba6c5ec1fbc710e08ebf95bb28b0864d differs only in Watch UI fixture/workflow reference fromc2e3a923; no production change. Focused11 failed65 after51.139seconds. The new controlled drag succeeded: header/error visible, valid replacement selected, issue gone and Start still disabled on simulator. The remaining failure occurs only after terminate/relaunch, when the picker reveal scans forward from below setup and never finds the virtualized picker above. The24-attempt failure is preserved; do not claim a passing recovery flow yet.

Before the next source edit: allow only the Watch UI test file's post-relaunch picker navigation to use the correct known direction/setup anchor after confirming actual frames/log. Preserve every preference/persistence/confirmation/invalid-state assertion and24attempt visibility/hittability checks. No production/other test change. Astra High diagnoses and freezes a minimal correction; parent uses a new manifest and bounded focused/full verification after owner awake confirmation. Run11 attachments/log/result remain failed evidence.

New completed baseline CI evidence8075991 run39255888191 shows actual failure, not a second timeout: shared suite105tests/3issues in productionWriterLeaseProtectsActiveAndPausedRecordingUntilSealed at MotionCaptureEngineTests348/349/351. All other tests passed; build duration538.15seconds. Exact job log retained as13-baseline-ci-8075991-job.log; artifact12188571201 exists. This contradicts the earlier impression of a persistent active stage; earlier pending observations were time-specific. Astra Extra High is investigating the concrete lease/state failure read-only before any engine/core-test correction. No automatic retries, weakened expectations or inferred root-cause fix.


## Revised Watch11 diagnosis before further fixture edits

Astra's preserved relaunch video23/26/35seconds disproves the initial restored-Capture hypothesis. Relaunch is at the top with the correctly persisted Backhand groundstroke title. That two-line title creates a147pt header;50pt drags again snap back before reaching setup. No direction-only change was applied. The working125pt low-inertia drag already revealed invalid header/error/picker and allowed valid replacement; the same tall-card handling is needed after relaunch and for any prior long selected title.

Approved revised fixture-only package before editing: same single Watch UI test file; retain existing24-attempt reveal helper and target assertions, but when on the foreground MAIN screen a visible/readable training header precedes an absent setup target, use the proven controlled0.85->0.35slow-held forward drag to leave that tall card. Keep normal short frame-directed scans elsewhere, do not apply this to native picker-screen lists, and preserve reverse normalization/visibility/hittability. This avoids per-case or title-specific assumptions when tests restore any valid prior choice. The unknown case may reuse the same bounded main-header navigation after asserting visible persisted title. No production, test preference values, assertion/loop weakening or automatic retry. Astra High implements only the justified fixture change, freezes and reports exact diff/hash; no UI test runs until owner confirms Mac lid open/unlocked.
