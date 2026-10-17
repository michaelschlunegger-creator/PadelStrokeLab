# Watch navigation contrast correction — evidence

17 October 2026. This supersedes affected Watch evidence for 9a77a32. The independent [review](../reviews/261017_PremiumUI_Review_9a77a32_v1.0.md) identified a white X on yellow native picker close button (~1.40:1). The one-line correction changes only the Watch NavigationStack tint from yellow to royal blue. Explicit yellow toggle/header/status remain. No behavior, test, dependency, signing or platform setting changes.

Current [25-file manifest](261017_PremiumUI_Code_State.sha256) SHA-256: `a66022dce9dfa8175595461f1e05563469a2dd4d474d0ed512c7c541d7199c99`. Against [the archived pre-contrast manifest](261017_PremiumUI_PreContrast_Code_State.sha256), only `PadelStrokeLab Watch App/ContentView.swift` changed. This bounds evidence invalidation: core29 and phone nine-execution test evidence in full scheme04 remain applicable to their unchanged production/test sources. Prior Watch build/visual tests are historical. Both Release products were rebuilt because the phone embeds the Watch.

| Affected verification | Result |
|---|---|
| iPhone Release, including embedded Watch | Exit0 / BUILD SUCCEEDED: `Logs/iphone-contrast-release.log`, `Results/iPhone-Contrast-Release.xcresult` |
| Watch Release | Exit0 / BUILD SUCCEEDED: `Logs/watch-contrast-release.log`, `Results/Watch-Contrast-Release.xcresult` |
| All Watch unit/UI tests | Exit0 / TEST SUCCEEDED: five executions / four distinct tests, zero failures/skips. `Logs/watch-contrast-ui-05.log`, `Results/Watch-Contrast-UI-05.xcresult`. Includes arm-change/reset/persistence, performance and both launch variants. |
| Native picker capture | `261017_Watch_Arm_Picker_Blue_Navigation.png`: inspected actual white close symbol on blue. Source white/royal contrast9.17:1; actual material differs, so this is not a pixel-level contrast certification. |

Same Xcode27 toolchain, simulator IDs and artifact roots as the [original UI evidence](261017_PremiumUI_Local_Evidence_v1.0.md). Same Release commands with distinct Contrast result/log paths. Watch test command uses the previous full-scheme command with `-only-testing:PadelStrokeLab Watch AppTests` and `-only-testing:PadelStrokeLab Watch AppUITests`, preserving the full affected suites; no retry flags. No phone/core source or assertion was weakened to obtain these results.

Current Watch captures have suffix `_Blue_Navigation`; old yellow picker capture is retained under `failed-evidence/261017_Watch_Arm_Picker_Yellow_Close_9a77a32.png`. Source manifest and whitespace checks pass. Required refreshed independent exact-HEAD verdict and hosted CI are tracked in draftPR1. Earlier review remains BLOCKED for its original code state.

Dark rendering, complete largest-text landscape visual audit, Watch large text and physical evidence remain open. Native final preview arrangement and Reduce Transparency cleanup still require owner Mac unlock. Physical installation is held pending simulator UI review; no merge/release authorized.
