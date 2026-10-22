# Existing-motion statistics Package A — local evidence v1.0

Date: 2026-10-20. Implementer: Astra Extra High, selected for bounded numerical interpretation and evidence-integrity work. Branch: `feature/guided-padel-setup`; starting/current implementation HEAD: `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. This package remains a local working-tree change, with no publication, merge, physical installation, or release claim.

## Authority and source identity

The director ratified the [Package A test contract](261020_Motion_Statistics_A_Test_Contract_v1.0.md), SHA-256 `9a6501a54153672c61d00de66c645c7d900145035f3a258c670b9c8ae13e906e`, after independent review of the [broader plan](../architecture/261020_Reference_Training_and_Statistics_Plan_v1.0.md), SHA-256 `f7c01e155b2e466afb57195c4877402aa2c1c9a5b95ac317d17d639796fc4f06`.

Private evidence root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-MotionStats`. Logs and result bundles below are relative to this directory. They contain synthetic test evidence. All Swift/Xcode invocations explicitly set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; Xcode 27.0 (27A266a), iOS/watchOS 27 SDKs.

Initial 69-entry freeze `04-source.sha256`: `a73cf4ddbf5fd2be40c3f7c2d123b510fc18341f168e05c18f38b520a662bf18`.

Corrected 69-entry freeze `12-source.sha256`: `f880024a9ad79a4c6d868834c5c1d4fdfeaff696d692ed12415043a2094ff0d0`. `12-freeze-delta.json` records the four changed entries relative to freeze04: iPhone model/statistics view and their two new app/UI test files. All 65 other entries match exactly. Final test-only freeze `19-source.sha256`: `cd0f9af6fd4d7bb3ea0873983c1f5d34441589edd9a8cc297cbf5ccb83b7ee9a`. Only `PadelStrokeLabUITests/MotionStatisticsUITests.swift` differs from freeze12; all production, core/app-host tests and existing UI tests are unchanged. The identical final manifest is saved in the working tree at [Motion Statistics A code state](261020_Motion_Statistics_A_Code_State.sha256). Focused UI20 passed all six cases; full final UI21 passed all 12 unique cases / 15 executions with zero failures. All 69 source entries were verified again after the final tests, exact fixture restoration and ordinary Release launch; `23-default-release-verification.json` records that confirmation.

Four production files, 465 changed lines relative to the preserved pre-package baseline, below the approved 1,200-line limit:

- `Packages/PadelCore/Sources/PadelCore/MotionStatistics.swift`: 228 lines, new.
- `PadelStrokeLab/RecordingLibraryModel.swift`: 96 changed lines.
- `PadelStrokeLab/RecordingDetailView.swift`: 9 changed lines.
- `PadelStrokeLab/RecordingStatisticsView.swift`: 132 lines, new.

The preceding P1 64-entry manifest (`ca4332e66eaf46077a99df949d1d9d0d20895917c02af21db0fce24b64b15171`) differs only in the two allowed existing iPhone files. Its other 62 entries remain byte-identical. No Watch capture, raw format/store, archive, transport, setup/profile, permissions, project, signing, or workflow source was edited by Package A.

## Behavior and test seams

The pure reducer validates all retained samples before active-interval filtering, computes magnitude peaks and stable scaled sum-of-squares RMS, and preserves actual timestamp extrema in at most 256 buckets/1,024 selected points per metric. Numeric overflow withholds the affected metric instead of reporting a plausible lower answer. Cancellation is checked at chunks and every 256 samples. The existing verified chunk-decode pass feeds the reducer; the library listing remains lightweight.

The iPhone shows wrist acceleration with gravity removed, wrist rotation in degrees per second, and expandable raw acceleration including gravity. Charts use discrete points only; pauses and gaps are not connected. Interrupted retained data is qualified; unavailable/corrupt/limited inputs withhold new statistics. Sample RMS is explicitly labelled as RMS of retained samples.

The separately ratified DEBUG fixture accepts only the fixed populated/unavailable/interrupted modes. It uses actual recording storage/codec/timeline in a fresh app-owned temporary directory, disables connectivity only for that fixture, and visibly says `SYNTHETIC UI REVIEW`. Ordinary launches and unsupported arguments do not activate it. No arbitrary path or fabricated sensor API is accepted.

A separately ratified internal DEBUG optional barrier runs only after a real repository detail review and immediately before the unchanged cancellation/generation publication guards. It defaults to nil and is compiled out of Release. Deterministic tests hold an older actual recording result, publish a different actual record with a different magnitude, then release the older task uncancelled. A separate test cancels an already-held in-flight task before releasing it. No sleeps, replacement loader, public test path, or changed publication guard was introduced.

`16-release-debug-exclusion.json` records Release executable SHA-256 `aee65b7ed2f0659de4f922d2454f7c22b6a29fa027aa81a19760f025c863d021`; neither executable strings nor symbols contain the fixture argument, fixture directory prefix, synthetic marker, fixture type, `detailReviewDidComplete`, or `DetailReviewBarrier`.

## Execution record

Simulator pair used for this verification: iPhone 15 Pro, iOS 27, `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`; Apple Watch Ultra 2, watchOS 27, `91757361-AEA2-41D8-9C4F-6DE5FF6365DA`. Phone tests use scheme `PadelStrokeLab`, Debug, explicit test-target filters, serial testing and signing disabled. Release builds use generic simulator destinations. Verification and cleanup are complete, with no remaining build/test jobs; the pair reservation is released with this handoff. No physical device action occurred.

| Evidence | Scope | Result |
|---|---|---|
| `01-core-red.log` | Reducer tests before production implementation | Expected RED: missing reducer. |
| `02-core-focused.log` | Initial focused compilation | Failed: test-helper default unlabeled parameter conflicted with sample arguments. Corrected to a labelled helper argument; assertions retained. |
| `03-core-focused.log` | Focused reducer tests | PASS: 10 tests. |
| `05-core-full.log` | Full core suite, freeze04 | PASS: 138 tests / 13 suites. |
| `06-phone-release.log` | iPhone Release, freeze04 | BUILD SUCCEEDED. |
| `08-phone-unit.log`, `.xcresult` | iPhone app-host suite, freeze04 | PASS: 12 tests / 3 suites. |
| `09-watch-release.log` | Watch Release, freeze04 | BUILD SUCCEEDED. |
| `10-phone-ui.log`, `.xcresult` | Initial full phone UI attempt | FAILED/PARTIAL. Missing child identifier; deliberately interrupted only the owned xcodebuild PID6919, exit75. Not a pass. |
| `11-ax-diagnostic.log`, `.xcresult` | Focused AX diagnosis before production correction | Expected failure reproduced; attached hierarchy proves parent identifier overwrote children. |
| `13-phone-unit.log`, `.xcresult` | Full phone app-host suite, freeze12 | PASS: 14 tests / 3 suites, including changed-selection and in-flight cancellation regressions. |
| `14-phone-ui.log`, `.xcresult` | Full phone UI suite, freeze12 | FAILED: 15 executions, one raw-disclosure query ambiguity. The other 14 executions passed; never count this full run as passing. |
| `15-phone-release.log` | Fresh iPhone Release, freeze12 | BUILD SUCCEEDED; DEBUG fixture/barrier exclusion verified separately. |
| `18-raw-focused.log`, `.xcresult` | Populated/raw flow after Button-only query correction, freeze17 | PASS: one test. Actual dark pixels mean its old light-labelled screenshots do not prove light mode. |
| `20-motion-ui.log`, `.xcresult` | Six motion cases with explicit appearance and whole-target visibility, freeze19 | PASS: six tests, zero failures. |
| `21-phone-ui-final.log`, `.xcresult` | Final full phone UI suite, freeze19 | PASS: 12 unique cases / 15 executions, zero failures; `TEST SUCCEEDED`, exit0. |

Core evidence carries forward by exact source identity: reducer SHA-256 `c8765c7204fc01473fefd04011e4dc3e2687b7d55f7e86c1b548654cfa86527e`, reducer-test SHA-256 `d55e8b5529d4c2995fcd91702f30f4f512bc9c2bdc2f1409147aee96e53e4730`. Every core and Watch source/test/project entry matches freeze04, so the full core pass and Watch Release build remain applicable without redundant reruns.

The authoritative final result summary `21-test-summary.json` reports `Passed`, 12 total/12 passed unique cases, 15 passed device-expanded executions, zero failed/skipped/expected failures, and no runtime warnings or test failures. The final UI run completed normally in 1497.828 seconds; its duration does not represent an interrupted or partial result.

## Preserved failures and corrective evidence

UI10 failed to locate `motionInterruptedNotice` after 135.975 seconds; the next large-text case also could not find its child identifier. A live simulator screenshot (`10-live-diagnostic.png`) showed the responsive actual synthetic-detail screen. This was not fresh evidence of a locked Mac. The owned runner was interrupted after the repeated failure pattern; `11-ui10-preservation.json` records the source/log hashes and cancellation receipt.

Failed UI runs also logged an Xcode supplemental simulator-diagnostic collection warning (`unable to find utility simctl`, exit 72). The selected developer directory was explicit, and the completed result bundles, activity trees, and attachments remain available. That warning is not evidence of a locked Mac or an alternative app root cause.

UI11 attached `11-ax-attachments/837C3E61-B211-4442-AB39-3F97BC8FF1BF.txt`. Its hierarchy showed the correct visible data (2 g, 180 degrees per second, 80 samples), but every motion child inherited `motionStatisticsSection`. The correction removes the unused outer container identifier and scopes the raw-disclosure identifier to its label. No content/assertion was removed.

UI14 then found that the native disclosure exposes both its Button and StaticText label with that identifier. The exact sparse accessibility tree is preserved in log lines 1362–1381. The test-only query now selects the Button explicitly. Focused UI18 passed with the expected 5 g assertion intact. `17-test-only-correction.json` records unchanged Debug app-binary identity and unchanged legacy UI test hashes.

Actual image inspection by the implementer and director then found that the screenshots named light were visibly dark: the launch argument had not switched device appearance. The original images are unchanged and explicitly rejected as light-mode proof in `14-visual-limitations.json`. The largest-landscape capture also put 2 g partly below the visible viewport; this is inadequate capture evidence, not evidence of a theme defect.

The reviewed test-only correction uses the public `XCUIDevice.appearance` API (present in the selected SDK, available since iOS 15), asserts its actual enum, and restores the original appearance in async MainActor teardown. Fresh pre-change simulator state was dark (`19-original-appearance.txt`). The scroll helper excludes the navigation overlay and requires the complete target frame to be visible whenever it fits, with fine movement near the target; fonts and production layouts remain unchanged. UI20 produced new original PNGs in `visuals20/`, indexed and hashed in `20-visual-manifest.json`. The implementer inspected actual light-mode pixels (pale canvas, white cards, dark status icons/values), readable expanded raw 5 g values, and the complete Peak 2 g target in largest-text dark landscape. The production layout and Debug app binary remained unchanged; the Debug dylib SHA-256 is `15b51961e053fbff62fb83f00e9c423642be0251945fa38af47d8d4d1a7dd12e`. The director independently inspected all seven original `visuals20/` files and reported no visual blocker: genuine light acceleration/rotation/raw; clear dark interrupted state and large portrait; corrected landscape with complete Peak 2 g; and a clear unavailable explanation with no fabricated zero. This file-only visual review is separate from automated assertions.

## Preservation, visual review and limits

The director's existing default-library synthetic recording `A6201020-0006-4000-8000-000000000001` was reversibly moved out for the existing empty-library UI test, only after explicit director approval. `07-root-fixture-move.json` records original/backup paths and all eight file hashes. No whole library was moved, deleted, or replaced. The exact two directories and all eight files were restored without replacement or deletion, as recorded in `22-root-fixture-restored.json`; every restored file still matched its original hash after the final ordinary launch.

The verified iPhone Release product was installed on the simulator and launched with no arguments after its bundle identifier (`23-default-release-launch.txt`). Version 1.0 / build 6 executable SHA-256 `aee65b7ed2f0659de4f922d2454f7c22b6a29fa027aa81a19760f025c863d021` exactly matches the tested Release15 binary. `23-default-release-verification.json` records installed-product identity, all eight restored file hashes remaining exact, all 69 frozen source entries matching, and appearance returning to the original dark setting. The inspected original screenshot `23-standard-release-home.png` shows the ordinary Practice / Padel Master home. The phone remains in landscape from the final legacy launch variant; original orientation restoration is not claimed.

Package A is frozen for director handoff. The requested black/turquoise/white theme is a separate subsequent package; no theme changes were included here. No Git mutation or physical installation was performed. The director owns the refreshed independent review and the remaining GitHub and physical-device gates.

No real Watch-signal, on-court accuracy, contact-quality, automatic shot count/classification, heart rate, step, distance, GPS, recovery, participant-isolation, or performance-on-hardware claim follows from these synthetic tests. Manual assistive-technology and physical-device acceptance remain separate. Current exact-HEAD CI, committed-source independent review, publication and owner-approved merge remain open. Earlier reviewed source is not a release-ready verdict for this local working tree.
