# Foundation local evidence — 16 October 2026

## Identity and scope

Branch: `chore/project-governance`. HEAD, local `origin/main` and live remote HEAD: `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; ahead/behind 0/0; no upstream and no PR. This commit does **not** contain the foundation: the generated project and foundation are still uncommitted. Existing uncommitted work was preserved.

The tested code is identified by [261016_Foundation_Code_State.sha256](261016_Foundation_Code_State.sha256), covering 22 source/configuration/asset files. Manifest SHA-256: `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`.

Relative to the verified pre-foundation archive, the bounded production change comprises six files and 308 changed lines (+284/-24). There is one Risk Level 3 domain: integrity of preliminary metadata and its serialization. Sensor/workout, concurrency, durable recordings, transfer, scoring and AI are outside this package.

Toolchain: Xcode 27.0 (27A266a), Swift 6.4, iOS/watchOS 27 SDKs. Explicit `DEVELOPER_DIR` is required; global command-line selection remains CommandLineTools. Both Release app Info.plists report minimum OS 27.0. All 12 deployment settings and six original targets are verified; signing team, bundle identifiers and companion relationship are unchanged.

## Results

- Shared package: **PASS**, 29 Swift Testing test definitions in one suite, including parameterized cases; zero failures.
- iPhone Release simulator build: **PASS**, exit 0.
- Watch Release simulator build: **PASS**, exit 0.
- iPhone full existing simulator suite: **PASS**, exit 0; seven executions, zero failures. Six XCTest launch/template executions plus one Swift Testing placeholder. Xcode reports four distinct tests because launch tests run in four configurations.
- Watch full existing scheme: **PASS**, exit 0; 12 executions across eight distinct tests, zero failures/skips. This scheme includes all four generated targets: four Watch XCTest UI executions, six paired-phone XCTest UI executions and two Swift Testing unit placeholders.
- Project syntax, original signing/bundle identity, deployment settings, six-target structure and whitespace checks: **PASS**.
- Historical PDF SHA-256 remains `939c5858420124a4fe3753e3812c7ad594f3a2755c7225b7f2ebe6c13238af25`.
- No automatic test retries were enabled. The generated performance test performs its normal repeated launch measurements; those are not retry-on-failure runs.

iPhone simulator: iPhone 17 Pro, `0A187E3D-DDD9-414B-B945-689E59923F32`, iOS 27.0 build 24A5408d. Watch destination: Apple Watch Series 11 (46mm), `E22A157D-E104-4182-A0FC-BB1B2B4A28CE`, watchOS 27.0 build 24R5347a, with existing iOS 27 iPhone 17 Pro Max simulator pair `BD67FBA0-D0EC-4B3F-9C4F-539AAA60896E`. These simulator models are not the owner's physical devices.

## Exact commands and artifacts

Working directory: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`.

Every build/test command below redirected stdout and stderr to the corresponding full log under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Logs/`. Result bundles are outside the source and Drive folders.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/PadelCore --scratch-path /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Core-Foundation > /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Logs/core-test.log 2>&1

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PadelStrokeLab.xcodeproj -scheme PadelStrokeLab -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation -resultBundlePath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Results/iPhone-Release.xcresult build CODE_SIGNING_ALLOWED=NO > /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Logs/iPhone-release.log 2>&1

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PadelStrokeLab.xcodeproj -scheme 'PadelStrokeLab Watch App' -configuration Release -destination 'generic/platform=watchOS Simulator' -derivedDataPath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation -resultBundlePath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Results/Watch-Release.xcresult build CODE_SIGNING_ALLOWED=NO > /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Logs/watch-release.log 2>&1

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PadelStrokeLab.xcodeproj -scheme PadelStrokeLab -configuration Debug -destination 'platform=iOS Simulator,id=0A187E3D-DDD9-414B-B945-689E59923F32' -derivedDataPath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation -resultBundlePath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Results/iPhone-Tests.xcresult -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO > /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Logs/iPhone-tests.log 2>&1

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PadelStrokeLab.xcodeproj -scheme 'PadelStrokeLab Watch App' -configuration Debug -destination 'platform=watchOS Simulator,id=E22A157D-E104-4182-A0FC-BB1B2B4A28CE' -derivedDataPath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation -resultBundlePath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Results/Watch-Tests.xcresult -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO > /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/Logs/watch-tests.log 2>&1
```

The parent's earlier 19-test package run is retained in `Logs/inherited-core-test.log`; it passed before the additional contract tests. It is not substituted for the final 29-test run.

Both app result bundles preserve the full simulator runs. Exported iPhone launch screenshots are under `Attachments/iPhone/` beside the Logs/Results folders. The inspected portrait image shows the forehand guidance and all five label names without visible clipping at the default simulator text size; this is not a full accessibility review.

## Warnings, failed operations and limits

All final production build/test commands passed; no build or test failure occurred in this package. Xcode emits an App Intents metadata-extraction warning because these targets do not depend on AppIntents; this app has no such feature. Test instrumentation logs a debugger-version lookup warning, while both suites complete successfully. The Watch run also logs simulator scene-configuration/accessibility-loader diagnostics; the result bundles report no runtime warnings or test failures. These diagnostics are retained in the full logs.

The implementation agent could not poll the parent's pre-existing test process (unknown session ID); the parent recovered the successful result and preserved its full log. A single attempt to save the large specification exceeded the tool's 64 KB request limit before writing; the complete snapshot was then saved in bounded chunks and checked. Neither event was a product/test failure or a hidden retry.

The existing app unit tests are empty generated examples; their pass status provides no model coverage. UI suites cover launch behavior and template launch performance only. The meaningful metadata validation lives in PadelCore tests. No durable archive writing, observed sensor rates, contact prediction, label timing/confidence, recording state machine, pairing, physical installation, permissions, background, battery or court evidence is present.

CI, committed-HEAD independent review, relevant physical iPhone/Watch checks, owner acceptance and approved publication/merge remain open. Passing these local checks does not complete WP1 or permit a merge-readiness verdict.
