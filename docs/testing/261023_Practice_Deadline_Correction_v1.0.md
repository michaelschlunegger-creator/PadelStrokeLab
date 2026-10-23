# Practice deadline correction

23 October 2026. Branch `feature/guided-padel-setup`; amendment base `e43eb7fb25dc2bcdafca7ab5ca060d3926a96d64`. This is a bounded data-integrity correction, not new recording scope. The practice limit remains30 elapsed minutes; sets remain limited to120 active seconds.

## Preserved failure and root cause

[CI39880508648](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39880508648) passed full Core388tests/29suites and both platforms' Release/Debug test builds and boots. Its Watch result contains130 tests:128 passed,2 failed,0 skipped. `enteredHeartRateRejectionKeepsItsActualEntryTimeAcrossOverdueEnd` and `practiceClockAndRecoveryDeadlinesDoNotResetAcrossSetsOrPauses` observed nil durable telemetry finalization. Four assertions failed across the two methods. Phone execution was still active when diagnosis began. The earlier [CI39878224843](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39878224843) passed all130 Watch tests with the same production inputs; that pass did not establish absence of this clock-dependent defect.

The first failure records monotonic anchor3234.779933041667. The coordinator constructs the terminal endpoint as `anchor + 1800`, yielding5034.779933041667. Subtracting the anchor from that endpoint yields1800.0000000000005. Core's subtraction-based upper-bound check therefore refuses its own intended endpoint. The coordinator reports incomplete evidence while durable telemetry remains open. This first failure is numerically explained and reproduced deterministically. The second follows the same path, but its exact anchor was not logged; it is not independently numerically proven.

Separate retained diagnostics show a test-host restart, a service-hub interruption and a120-second simulator boot timeout. An application crash cause remains unproven. The final result still covers all130 tests. This infrastructure observation is not claimed resolved by the numerical correction. Earlier simulator failures remain in [CI isolation evidence](261023_CI_Platform_Isolation_v1.0.md).

## Ratified correction and invariants

Independent review ratified the five-file plan before production changes:

- `OwnerPracticeTelemetry.swift`: validate admitted instants and finalization against the same canonical absolute deadline, retaining lower bounds, finite-value validation, existing errors, refusal reasons and capacity rules. No epsilon, tolerance or admission beyond `deadline`.
- `OwnerPracticeCoordinator.swift`: change only the three corresponding duration-cutoff comparisons. Actual native/resource closure, writer/callback drain, frozen raw bounds and terminal endpoint construction remain unchanged.
- Existing Core telemetry tests: deterministic awkward anchor, exact endpoint and immediately adjacent values; observation/event/finalization plus durable encode/decode; rejection preserves prior admitted evidence and duration-limit refusal.
- Existing Watch lifecycle tests: baseline-only deterministic clock, timer/direct-End paths, native-ended/drain requirements, persisted terminal state and no issue on successful publication. Injected publication failure must retain open evidence and a visible incomplete-evidence issue. Existing failing methods and five-second waits remain intact.
- `project.pbxproj`: all12 configurations move build6 to7; marketing version, signing, entitlements, deployment targets and schema/calculation versions remain unchanged.

Old valid serialized evidence stays readable and is not rewritten. No capture, identity, consent, transport, export, Health authorization or UI feature is added.

## Verification contract and observations

Xcode27.0 (27A266a) and27.0 SDKs are required with explicit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` locally. Every failure remains retained under private `O12-CanonicalDeadline` evidence.

The first Core red run exposed the intended exact-endpoint failure plus an incorrect test observation kind. That fixture was corrected before production changes; the second retained red run fails only the intended exact endpoint with `invalid("practice time")`. The companion adjacent-boundary/refusal case passes before the fix. After correction, focused telemetry passes35 tests in19.968seconds and full Core passes390tests/29suites in284.969seconds, exit0. Generic Watch Debug build-for-testing succeeds, exit0, without creating or booting a simulator. Before/after inventories match. This compilation is not Watch execution proof.

Independent review clears the exact five-file141+/24− source diff and the documented runtime route. Both generic Release builds pass and report version1.0/build7. A fresh signed generic-device build succeeds with embedded Watch; both deep/strict signatures, companion identity, unexpired profiles and coverage of the known physical devices pass. Old build6 binaries are not used for this correction. Private `O12-CanonicalDeadline` retains these build/result/signing receipts.

The subsequently completed phone CI result passed all27 UI executions but failed one app-host independent-reader fixture. Its separately ratified [three-line test isolation correction](261023_Phone_Review_Fixture_Isolation_v1.0.md) passes focused12/18 and full app-host74/125, zero failures/skips. Production inputs and signed build7 are unchanged by that sixth test-file amendment.

Final Source11 freezes115 inputs. Relative to Source9, exactly the five deadline/build paths and one phone test path differ; Source10 retained the initial five-file freeze. Current manifest SHA256 `913511f978b91aaccedc8e98c088df545ead81b8fdd9f4ad71d413ea47aa17ec`. Exact-head full CI and committed review remain required; source-level clearance and local builds do not establish a runtime or physical pass.

Local Watch inventory reports two available watchOS27.0 bundles sharing one runtime identifier, builds24R5347a and24R362. Existing simulators are left untouched. Independent review approves generic watchOS Simulator test-product compilation as compilation evidence only. Local Watch execution is unavailable; it is not claimed passed. The full unchanged Watch suite, including the new tests, must actually pass on exact-head CI's validated single OS27 runtime. Full Core, both Release builds, fresh signed build7 products, full phone CI and final foundation success remain required. This changes the execution route, not test coverage or acceptance gates.

## Closure requirements

Record final local results and source identity, publish the focused branch, complete full exact-head CI and committed review, then install/verify/launch phone and Watch separately. Old signed build6 evidence cannot establish the corrected build7. No installation, physical sampling, merge or release is claimed here.

Live exact-commit outcomes attach to [PR#3](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/3) without changing tested HEAD merely to record later observations. Physical permissions, sampling/background continuity, transfer/export and battery behavior still require the controlled owner dry run.
