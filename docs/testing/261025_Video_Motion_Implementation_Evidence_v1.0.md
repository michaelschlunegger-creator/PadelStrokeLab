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

## Current limits

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

## Current feature limits

No native camera capture, synchronisation, transport, replay, export/deletion or
physical behavior for this feature has passed yet. The existing baseline CI is
not feature evidence. Do not call this branch court-ready or merge-ready.
