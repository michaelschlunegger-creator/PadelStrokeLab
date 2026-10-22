# Largest-text landscape scroll driver correction

23 October 2026. Branch `feature/guided-padel-setup`; amendment base `a56ebeea51d7395bed9e2b36c77ae02c09105f3c`. One UI-test helper changes. App/Core production, storage, permissions, sensors, builds and all assertions remain unchanged.

## Preserved failure and diagnosis

[CI39847924301](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39847924301) FAILED. Full Core and both Release builds passed. The full phone run had27 UI executions with exactly one failure: `MotionStatisticsUITests.testLargestTextDarkLandscape` could not reveal the home Sessions button; Watch CI was skipped. This is failed evidence, not a successful validation run.

Downloaded result attachments show target `(136,97,602,293.3)`, scroll viewport `(0,0,874,402)` and navigation bottom78. Existing usable frame is `(4,86,866,296)`. The target fits, but full containment leaves only2.7 points of positioning tolerance. Repeated9.6-point pans make no progress. Screenshot text is legible; no production UI defect is established by this failure.

The bounded Astra correction measures actual target movement after each requested pan. It compensates the next precise recenter gesture for observed pan activation loss, bounded at20% usable height; the existing70% gesture cap remains. No fixed minimum final displacement is imposed. Full containment for fitting targets, the existing oversized-target midpoint rule, hittability,40attempts, screenshots, accessibility audits and all assertions remain unchanged. Independent review clears the source correction subject to runtime evidence.

## Source identity and verification

`Privacy-Final-Source4` freezes all115 build/test inputs. Manifest SHA256 `c86185ed03210a8048ab8c85456ddd9be580d1d2ddef868d05cf3f408d29f956`. Only `PadelStrokeLabUITests/MotionStatisticsUITests.swift` differs from Source3. All app/Core production and non-Motion test inputs are identical; existing Core, Watch, phone host, Release and signed-product evidence retains input identity. The affected Motion UI suite requires fresh evidence.

- `Privacy-CI3-01-ui-driver-build`: Xcode27 Debug build-for-testing PASS.
- `Privacy-CI3-02-landscape`: PASS,1method, zero failures/skips,100.541seconds.
- `Privacy-CI3-03-motion-regressions`: all six remaining affected methods PASS, zero failures/skips,289.828seconds. The already-passing landscape method is not duplicated locally; full CI runs every method.
- New exact-head CI and final independent committed review: PENDING publication.

No unchanged automatic retry, test exclusion, reduced assertion or simulator-size substitution is used. Prior failures remain retained in the private result bundles/logs and linked GitHub run. No candidate installation or physical sensor validation is claimed. Subsequent exact-head CI/review and separate device observations belong on PR#3 and linked evidence without changing tested source merely to record outcomes.

## Aggregate CI scheduling budget

Actual CI2 timings were11m43 simulator creation,12m24 Core,5m45 Release builds,3m42 test builds and53m20 phone tests; the job completed87m48 with Watch skipped. Adding the measured5m44 Watch run gives93m32, already beyond the90-minute aggregate limit. Independent non-Astra review approves raising only that aggregate cap to120 minutes, providing about28% margin over this measured lower estimate. Core remains15 minutes; all per-test deadlines, assertions, complete CI suite coverage and no-retry policy remain unchanged. This budgets mandatory work and does not guarantee completion.

`Privacy-Final-Source5` differs from Source4 only in that workflow budget. The current115-input manifest SHA256 is `f374785cdd9784728de4f7d98a8e42c2c9614eb378d3509ef086dd27d1f6849f`. Only the Motion UI helper and workflow differ from Source3. All app production and signed-product inputs remain identical.
