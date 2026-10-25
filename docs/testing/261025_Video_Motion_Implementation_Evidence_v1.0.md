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

## D / F0 — tests-first compilation evidence

D: new319-line `PhoneVideoWriterTests.swift`,8tests, SHA-256
`0b822b5cb9c85b27dea7b9aa4173eb9c30d3e299c52612a42e8d893131eb6743`.
Root Xcode27 `build-for-testing`, generic iOS Simulator, writer tests only,
signing disabled: **expected RED,exit65**, missing
`VideoMotionMediaConfiguration`/`PhoneVideoWriter`/`PhoneVideoWriterFaults`;
`/tmp/padel-video-motion-d-red.log`. Actual pixel/PCM fixtures will exercise the
real encoder/decoder without camera/microphone hardware after implementation.

F0: new126-line `VideoMotionEvidenceTests.swift`,6tests, SHA-256
`df8590c0dd28f6c0e927199bc1f78d67d887cd25444e3f1ac22e5a5d6c944de7`.
Root Xcode27 Swift Core test command, `--no-parallel --filter
VideoMotionEvidenceTests`: **expected RED,exit1**, missing evidence types and
Session evidence APIs; `/tmp/padel-video-motion-f0-red.log`.
No D/F0 production changes existed for those respective RED runs. Director
releases disjoint bounded D/F0 production afterwards; native verification waits
for both source freezes. These are compilation contracts, not test execution.

## D / F0 — independent test-contract challenge

Independent review required decoded frame/sample coverage against known fixture
inputs, initial per-track append failure/missing-track cases, a positive Go path,
invalid native bridge provenance and a frozen pre-evidence byte fixture.
D tests were expanded to382lines/10tests without weakening prior assertions;
SHA-256 `cf5f8bdf51718cede9899e7a423700550bfe862ab989e62f39e7ae4ceeca771b`.
The original RED/SHA remains retained. No D production file existed then.

A further native build-for-testing attempt failed **exit65** before reaching D
tests because concurrently written, unfinished F0 `VideoMotionEvidence.swift`
had a missing return in its clock-range getter. Log:
`/tmp/padel-video-motion-d-red-2.log`. This is an unrelated failed compile, not
D RED proof or a failed native test. Root will wait for both authors' explicit
source freezes before further shared native verification. The expanded D test
contract was defined before D implementation; the original missing-API RED is
unchanged. No absence-only retry is required.

## F0 — expanded contract and historical fixture

F0 expanded to241lines/10tests, SHA-256
`837c96b74de137695ecdea10e0aab909129c7e1949e0b3dea135fb6f999959b1`,
before the related semantic correction. New cases include successful Go,
nonzero source/runtime offsets, missing prerequisites, terminal protection and
a byte fixture generated from committed `ce9fde847bf158e0df3af219edf442c0780b0d77`.
The isolated old-source `HistoricalFixture` executable used Xcode27 Swift, its
own `/tmp` archive/scratch, and exited0. Log:
`/tmp/padel-video-motion-f0-historical-ce9fde8-build.log`. Old Session source SHA
`152819b7909f67e9569b99b407bd37cdd28ee8c1e99193ebcbc824be40bebd08`;
2216fixture bytes SHA `967a0c24892713490b39c551e3c1a40dbd88f8d4a4259bff8c508ab1ff752775`.
The fixed bytes/provenance are embedded in the test; no owner recording is used.

Root expanded F0 run2 exited1 at test compilation: throwing expressions combined
inside SwiftTesting expectations require precomputed values/simple assertions.
No semantic tests ran. Log `/tmp/padel-video-motion-f0-red-2.log` is retained.
The unrelated initial getter compiler defect had been corrected without changing
behavior. D Core media compiled in run2; root requested a test-only syntax fix
before exercising the new positive/nonzero-offset paths.

## F0 — semantic RED verified

After test-only SwiftTesting syntax corrections,243-line test SHA-256 is
`1a16fe94f7c22e68d294da832233b69829d1b8bdab3a89155c8f4953d5776351`.
Root run3 compiled and executed: **10tests,9passed/1expected semantic failure,
exit1,1.179seconds**, `/tmp/padel-video-motion-f0-red-3.log`.
The failing positive test is
`supportedGoConvertsMeasuredNonzeroSourceOffsetsBeforeMappingCoverage`:
the first Evidence implementation checked native source timestamps directly
against runtime mapping coverage instead of applying the retained source-clock
bridge. The positive zero-offset/missing-fact tests, terminal/identity tests and
frozen historical byte fixture passed. Director releases only the targeted
bridge-consumption correction; assertions remain unchanged.

## F0 — retained timing/control history verified

Astra corrected only the evidence coverage gate: intersect same-domain source
bridges and convert native times into outward-rounded runtime intervals; both
interval endpoints require supported cross-device coverage. No midpoint or
zero-offset substitution. Root repeated the VideoMotion/connectivity/preparation
regression command: **PASS,exit0,87tests in10suites,6.310seconds**,
`/tmp/padel-video-motion-f0-green.log`. Tests were unchanged after semantic RED.
Two production paths plus243test lines total approximately531changed lines.
Manifest: `261025_Video_Motion_F0_Source_v1.0.sha256`.

Integration finding: the older B live reducer needs the same bridge-aware gate.
Director ratifies separate B1 before orchestration/exposure, with optional
backwards-compatible native-fact bridge fields, mandatory supported bridge
evidence for live Go, and shared interval validation. F0 alone is not live
combined-start proof. D Core storage is released after this frozen-source pass.

## Current implementation limits

No physical camera capture, cross-device synchronisation/transport, playable
recording/replay or export/deletion for this feature has passed yet. Local camera
lifecycle tests passed; acquisition is not persisted media. The baseline CI is
not feature evidence. Do not call this branch court-ready or merge-ready.
