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

No native camera capture, synchronisation, transport, replay, export/deletion or
physical behavior for this feature has passed yet. The existing baseline CI is
not feature evidence. Do not call this branch court-ready or merge-ready.
