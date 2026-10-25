# Local video/motion implementation evidence

25 October 2026. Branch `feature/watch-video-motion`. App source baseline
`2e6e4df46040c48dd2aaae0e19c3bdfbbad7dde8`; published planning checkpoint
`60c8af853154963b94bbe355c1b6aeab2cf8aefd` changes documentation only.
Xcode 27.0 (27A266a), iOS/watchOS27 SDKs verified; every Swift/Xcode invocation
uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Foundational architecture/production/tests: requested Astra Extra High.
Ordinary verification/documentation: root. Independent architecture challenge:
separate non-author non-Astra High reviewer; see the linked architecture review.

## A0 — tests-first checkpoint

Before production changes, Astra added only
`Packages/PadelCore/Tests/PadelCoreTests/VideoMotionAdmissionTests.swift`, SHA-256
`1178d24236d234664ac3a3340230d1201cc5bbd67a35a5b3b76052b2d9019017`.
Root verified Git status showed that single new test file and no production diff.

Command:

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test \
  --package-path Packages/PadelCore --scratch-path /tmp/padel-video-motion-core \
  --filter VideoMotionAdmissionTests
```

Result: **expected RED, exit1 at compilation**, because the proposed
`RecordingCaptureMode` type and `captureMode` APIs do not exist in the baseline.
No test execution or passing assertion is claimed. Full local compiler output is
retained at `/tmp/padel-video-motion-a0-red.log`; its absence of those symbols is
the expected contract gap. This is not a simulator/device failure or an
unexpected regression. Implementation and GREEN verification follow separately.

## A0 — GREEN and compatibility regressions

Astra changed four allowed Core production files (50 additions, 12 deletions)
and retained the tests-first file unchanged. No phone/Watch UI, native capture,
Health, storage codec or transport implementation changed. Package total,
including the new tests: 262 added/deleted lines, within its six-file/2,500-line
budget. Root reviewed the diff and `git diff --check` passed.

Root ran the same toolchain/package/scratch-path command with filter:

```text
VideoMotionAdmissionTests|OwnerRecordingContextTests|OwnerPreparationMessagesTests|OwnerPreparationTransportTests|PracticeSetupChannelTests|PracticeSetupStoreTests
```

Result: **PASS, exit0, 117 tests in 7 suites, 94.628 seconds**. The new
`VideoMotionAdmissionTests` suite passed in 3.689 seconds, including exact legacy
canonical fingerprints and new mixed-mode admission. Local output:
`/tmp/padel-video-motion-a0-green.log`. The filter also selected existing lifecycle
channel coverage. Final complete Core verification will follow the integrated
feature with the CI's serialized `--no-parallel` setting.

A diagnostic termination command was issued just as the process finished; both
PIDs were already absent and no signal was delivered. The original test invocation
completed normally with exit0; no retry or repeated GREEN run occurred.

These are pure Core/local compatibility results, not camera/Watch behavior,
physical sync proof, full-suite CI or independent committed-HEAD clearance.

## A — local sidecar/annotation storage

Tests-first checkpoint contained only two new test files and no A production
paths. Root ran the same explicit toolchain/package/scratch-path with
`--no-parallel --filter 'VideoMotion(Store|Annotation)Tests'`.
Expected RED: compilation exit1 for missing `VideoMotionBinding` and
`VideoMotionStoreStage`; output `/tmp/padel-video-motion-a-red.log`.
Original test SHA-256 values:

- Store: `fba93acdb82cc938512969ebf9cec7500347af7fdb224c2557b35febc57526e4`.
- Annotations: `d6c701c6d26a3c0ca32e356dbfc2d72d3c6a6d0922bfd365c5ff0dbaaeff35b6`.

Astra implemented three allowed production files. One genuine fixture error was
corrected: independent bindings used the same fixed reserved recording ID, making
unrelated sessions collide. The helper now supplies distinct UUIDs; an explicit
duplicate-recording-ID rejection assertion was added. This strengthens the
reservation rule. The initial source passed **25 tests/3suites**, exit0,
0.304seconds, including A0, in `/tmp/padel-video-motion-a-green.log`.

Before source freeze, self-review identified a link/unlink publication crash
window that could leave a strict-reader-rejected hard link. Root authorized only
the same-file atomic exclusive-rename correction and one competing-revision
regression. No existing raw/filesystem helper was changed. Final source budget:
879lines across three production and two test files, one risk domain.

Root reran because those source/test inputs changed, using
`--no-parallel --filter 'VideoMotion(Store|Annotation|Admission)Tests'`.
Final result: **PASS, exit0, 26 tests in3suites, 0.326seconds**; output
`/tmp/padel-video-motion-a-final-green.log`. Root reviewed the session/store source,
including the existing sorted/no-follow file helpers. The retained first pass is
not substituted for this changed-source result. Source manifest:
`261025_Video_Motion_A_Source_v1.0.sha256`.

## B — timing and pure control protocol

Before production, only new `VideoMotionTimingTests.swift` and
`VideoMotionProtocolTests.swift` were present. Expected RED command used
`--no-parallel --filter 'VideoMotion(Timing|Protocol)Tests'`; exit1 for missing
`VideoMotionClockExchange`/`VideoMotionClockMapping`, retained in
`/tmp/padel-video-motion-b-red.log`. Original test SHA-256:

- Timing: `a807fcee390d1d730972c32d675fad5377b058d808dcdab68d13841cb5c8c688`.
- Protocol: `be046d1c427106b6ebf35b3fcc2162dc290cc8df258e33ed20144e3883b9b301`.

Astra added two production files, 732lines including unchanged tests; no A model
or canonical bytes changed. Root ran the same toolchain/package/scratch-path with
`--no-parallel --filter 'VideoMotion.*Tests'`: **PASS, exit0, 37 tests in5suites,
0.349seconds**, `/tmp/padel-video-motion-b-green.log`. Root reviewed the timing
and reducer source. Source manifest: `261025_Video_Motion_B_Source_v1.0.sha256`.

The protocol is pure; native adapters still must validate current authority,
persist receipts/facts and prove appended media/completed motion writes. Its
capturing phase alone is not combined readiness. Clock observations are bounded
to32; integration must reserve startup/stop observations and use a sufficiently
spaced periodic probe cadence rather than the2-second status heartbeat cadence.
Mapping requires3observations spanning at least5seconds and refuses extrapolation.
Run epochs differ from raw/native clock domains and require explicit conversion.
Manual alignment revisions remain H scope; no linked replay is implemented yet.

## C — tests-first native camera checkpoint

Only new `PadelStrokeLabTests/PhoneVideoCaptureTests.swift` was added for C;
SHA-256 `dad255509647624c0f634ce0aac2717b2091d84d44a88965f506ac72b205d115`.
It contains10tests. Root used Xcode27 `build-for-testing`, project
`PadelStrokeLab.xcodeproj`, scheme `PadelStrokeLab`, generic iOS Simulator,
DerivedData `/tmp/padel-video-motion-native`, only
`PadelStrokeLabTests/PhoneVideoCaptureTests`, signing disabled.

Result: **expected RED, exit65 at compilation** for missing
`PhoneVideoIdleTimer`, `PhoneVideoCaptureHardware`, `PhoneVideoFormat` and
`PhoneVideoSample`; output `/tmp/padel-video-motion-c-red.log`.
This is not test execution, native acquisition evidence or a simulator failure.
No C production changes existed at that checkpoint. B's shared library compiled
for the native build; full platform verification remains required later.

## E — sole-delegate control and clock routing

Tests-first SHA-256: `277f1a6e1129304d01bc5af08c2ab4650c6e9b2323f54c09bdaf015013e1203f`.
Root expected RED used `--no-parallel --filter VideoMotionTransportTests`:
compile exit1, missing transport Scope/Adapter/Request; local
`/tmp/padel-video-motion-e-red.log`. Astra then changed only new
`VideoMotionTransport.swift` and the existing `RecordingConnectivity.swift`,
753total changed lines including262unchanged test lines.

With C/E source frozen, root used
`--no-parallel --filter 'VideoMotion.*Tests|RecordingConnectivityTests|OwnerPreparationTransportTests'`:
**PASS, exit0, 72 tests in8suites, 5.014seconds**,
`/tmp/padel-video-motion-e-green.log`. Root inspected the distinct wire frames,
scoped identities and limits. Manifest: `261025_Video_Motion_E_Source_v1.0.sha256`.
This is Core routing/clock-boundary proof, not real Watch transport/camera proof.

## C — first implementation build retained as failed evidence

Root booted the existing iPhone15Pro simulator on iOS27 (both boot/status exit0),
then ran `xcodebuild test`, scheme `PadelStrokeLab`, only
`PadelStrokeLabTests/PhoneVideoCaptureTests`, signing disabled, parallel testing
disabled. DerivedData `/tmp/padel-video-motion-native`; results
`/tmp/padel-video-motion-c-green-1.xcresult`, log with the same stem.

Result: **FAIL, exit65 during compilation**; no camera tests executed.
Swift Observation requires a single mutable declaration per tracked property.
Three multi-binding declarations produced `_sceneActive/_closed`,
`_operation/_generation` and `_previousIdleTimer/_deadline` macro errors.
Initial source is frozen in `261025_Video_Motion_C_Compile1_Source_v1.0.sha256`.
Astra corrected only those three declarations into six individual lines, without
test/behavior changes. A new native result bundle/run is required after current
Core source edits quiesce; the failed run is not overwritten or relabelled.

## A1 — retained access correction tests-first

The independent foundation source review found normal authority advancement would
block completed-session edits; see the separate source review/correction contract.
Astra added only `VideoMotionRetainedAccessTests.swift`, five tests, SHA-256
`9bb1b61a63615bc946dbbe9a81ecb4f0c5c3531ae14dc770b13dd872ed4a786d`.
Root command `--no-parallel --filter VideoMotionRetainedAccessTests` produced
expected compile **RED, exit1** for missing `readRetained`/`publishRetained` APIs,
`/tmp/padel-video-motion-a1-red.log`. A1 production has not yet been changed at
that checkpoint. It preserves exact-live admission and adds separate retained
permissions; full withdrawal/deletion remains blocking.

## A1 — retained access verified

Root ran Xcode27 Swift Core tests with `--no-parallel` and filter
`VideoMotion.*Tests|RecordingConnectivityTests|OwnerPreparationTransportTests`:
**PASS, exit0,77tests in9suites,5.141seconds**, local
`/tmp/padel-video-motion-a1-green.log`. This includes five tests covering normal
End/HR changes, withdrawal/reconsent, foreign/stale authority, CAS/deletion and
real pending restrictions. Live admission stays exact-original; retained edits
use a fresh channel snapshot. Two production paths and one test add172lines.
Source manifest: `261025_Video_Motion_A1_Source_v1.0.sha256`.

## C — second implementation build retained as failed evidence

After the Observation correction, native camera check2 failed **exit65 at
compilation**, `/tmp/padel-video-motion-c-green-2.log` and matching `.xcresult`.
No tests executed. Swift27 rejected MainActor properties accessed from the
nonisolated deinitializer. Astra applied the compiler-recommended `isolated
deinit` modifier; cleanup and tests are unchanged. Native check3 uses a new
result path and remains pending at this checkpoint. Neither failure is hidden.

## C — foreground acquisition lifecycle verified locally

After the isolated-deinitializer correction, root ran Xcode27 `xcodebuild test`,
scheme `PadelStrokeLab`, iPhone15Pro/iOS27 simulator, camera tests only, signing
and parallel testing disabled. **PASS, exit0,10tests in1suite,0.026seconds**;
`/tmp/padel-video-motion-c-green-3.log` and matching `.xcresult`.
Native acquisition stays disabled for simulator/test/fixture launches; tests
exercise production lifecycle with hardware isolation and actual CoreMedia
buffers/clocks. This is not physical camera/microphone, writer or video evidence.
Production scope is602-line acquisition model,75-line preview and four usage
description lines; with263test lines the package is944lines. Manifest:
`261025_Video_Motion_C_Source_v1.0.sha256`. No navigation exposes capture yet.

## Current implementation limits

No physical camera capture, cross-device synchronisation/transport, playable
recording/replay or export/deletion for this feature has passed yet. Local camera
lifecycle tests passed; acquisition is not persisted media. The baseline CI is
not feature evidence. Do not call this branch court-ready or merge-ready.
