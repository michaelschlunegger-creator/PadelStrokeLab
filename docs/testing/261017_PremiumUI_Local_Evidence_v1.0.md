# Premium preparation UI — local evidence

17 October 2026, Asia/Dubai. Branch `chore/project-governance`; starting/published preparation HEAD `cfea609203a68f3195cc5f864060bc356403a605`; unchanged base/main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. Source identity for this increment is [the 25-file manifest](261017_PremiumUI_Code_State.sha256), SHA-256 `9baaf3aa7cb5b73680d0e071d546f271c395dc348549b6caa92a1c5274dc08b2`. Documentation and screenshots are outside that runtime/test fingerprint. Old foundation evidence remains historical.

## Scope and results

Astra High implemented the shared presentation package and both views; coordinator verification added meaningful UI workflows and corrected accessible status/selection metadata. Five production files: PadelDesign manifest/source, phone ContentView, Watch ContentView, Xcode local-package integration. No sensor, recording, connectivity, scoring, AI, signing, permissions or deployment changes.

| Check | Result and practical limit |
|---|---|
| Xcode/SDK | Xcode 27.0 (27A266a), iOS/watchOS 27. All commands explicitly select `/Applications/Xcode.app/Contents/Developer`. Global selection stays CommandLineTools. |
| PadelCore | 29 tests passed; UI changes do not change these sources. `Logs/core-tests.log`. |
| Final iPhone Release | Exit 0, BUILD SUCCEEDED. `Logs/iphone-final-release.log`, `Results/iPhone-Final-Release.xcresult`. |
| Final Watch Release | Exit 0, BUILD SUCCEEDED. `Logs/watch-final-release.log`, `Results/Watch-Final-Release.xcresult`. |
| Phone regression02 | Exit 0: three navigation workflows passed, including largest-text portrait and landscape. `Results/iPhone-UI-Regression-02.xcresult`. |
| Full Watch scheme04 | Exit 0, TEST SUCCEEDED: all four phone/Watch app test targets, 14 executions / 10 distinct tests, zero failures/skips. `Results/Watch-Full-UI-04.xcresult`. |
| Source/format | All 25 manifest entries verified; git diff whitespace check passed. |
| Workflow syntax | actionlint 1.7.12 passed with only its documented unknown `xcode-27` runner-label catalog diagnostic ignored; shellcheck/pyflakes unavailable and disabled. Hosted execution remains a separate gate. |

The phone flow verifies both guides, all five reference headings, back navigation and the explicit unavailable-recording notice. Largest text remains scrollable; tests require an element center inside the viewport before tapping. The Watch flow verifies selection, confirmation, reset on arm change, persisted arm and cleared confirmation after fresh process launch. Existing generated unit/launch tests are smoke coverage only. No sensor, pairing, battery, VoiceOver audit or physical usability conclusion follows.

## Reproduction and artifacts

Private local artifact root: `~/Library/Developer/Xcode/DerivedData/PadelStrokeLab-PremiumUI/` (Logs, Results, Attachments). Final Release products use `~/Library/Developer/Xcode/DerivedData/PadelStrokeLab-PremiumUI-FinalRelease/`. Build products/result bundles stay outside Git/Drive. Public evidence contains simulator views only.

Every command has prefix `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Release commands: `xcodebuild -project PadelStrokeLab.xcodeproj -scheme <scheme> -configuration Release -destination <generic destination> -derivedDataPath <FinalRelease> -resultBundlePath <unique result> CODE_SIGNING_ALLOWED=NO build`; scheme/destination pairs are `PadelStrokeLab` / `generic/platform=iOS Simulator`, and `PadelStrokeLab Watch App` / `generic/platform=watchOS Simulator`.

Full suite command uses `xcodebuild -project PadelStrokeLab.xcodeproj -scheme 'PadelStrokeLab Watch App' -configuration Debug -destination 'platform=watchOS Simulator,id=91757361-AEA2-41D8-9C4F-6DE5FF6365DA' -derivedDataPath <PremiumUI> -resultBundlePath <Results/Watch-Full-UI-04.xcresult> -parallel-testing-enabled NO test`. No retry flags. Phone simulator: `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`, iPhone15Pro OS27.0; Watch simulator: ID above, Ultra2 OS27.0. Both were created for this review.

## Preserved failed attempts and corrections

- Initial phone full suite01 passed standard navigation. Initial Watch suite01 failed the status query and an alternate phone navigation flow. Results/logs are retained, never overwritten.
- Watch status was not exposed as the intended accessible row. The status/notice container now combines its children and owns `watchSetupStatus`.
- Watch regression02 failed reaching confirmation after choosing the already selected Left arm; the native picker remained open. Regression03 exposed that the native picker query did not provide its selection. Explicit accessible selection metadata now exposes Left/Right; the test validates it and exercises an actual arm change. No AppStorage key/state semantics changed.
- The first alternate phone test trusted `isHittable` while the large-text button was outside the useful viewport. Centered bounded scrolling and explicit portrait/landscape setup fixed the automation; both workflows passed in regression02 and full suite04.
- XCTest landscape attachments contain cropped/black regions; these are retained under `failed-evidence/` as rejected visual captures, despite functional assertions passing. They are not used as proof of visual quality. A direct simulator screenshot showed a full landscape surface. A complete final large-text landscape visual audit remains open.
- A diagnostic Python image read failed because PIL was unavailable; no dependency was installed. An attempted simulator termination found no running phone process. Neither was an app build/test failure; console outputs remain in the session record.

## Visual review and limits

Accepted standard-size captures under `docs/design/screenshots/` cover phone home, both guides and lower reference content, plus Watch setup/picker/confirmed/fresh-launch states. Shared palette: navy/royal blue, yellow accents, white/pale-blue cards; native glass action/navigation, opaque reading surfaces and a solid action fallback for Reduce Transparency. Source-color contrast checks: white/royal 9.17:1, navy/yellow 12.62:1, light secondary/white 6.55:1, dark secondary/Watch surface 9.66:1. These are token calculations, not a complete accessibility audit.

Largest-text portrait captures were inspected; all five labels were reachable. Reduce Transparency was visibly ON in Device Hub during regression checks. Dark appearance was requested but tested app captures remained light; dark rendering is **not verified**. Watch CLI text-size/appearance controls report unsupported; do not claim Watch large-text verification.

Xcode27 uses Device Hub (`com.apple.dt.Devices`) for live simulated devices; absent standalone Simulator.app is not a preview blocker. Official references: https://developer.apple.com/documentation/xcode/device-hub and https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices . The apps were launched in Device Hub during review. Final Release apps were installed/launched only on the two named simulators. Phone system text size was restored to large. The Mac locked before final portrait/window arrangement and Reduce Transparency restoration; unlock is required to finish these native UI actions. Do not claim final live-preview handoff or dark/reduced-transparency cleanup completed.

Physical installation remains on explicit owner hold pending simulator UI review. Hosted CI on the preceding HEAD failed to boot Watch with CoreSimulator401 runtime-profile mismatch (run39026964171); this does not establish a code defect or clean CI. Refreshed exact-HEAD review, clean hosted CI, relevant physical evidence and owner merge approval remain separate gates.
