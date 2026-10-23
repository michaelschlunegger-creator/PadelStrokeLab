# Playing-arm setup UX verification v1.0

23 October 2026, Asia/Dubai. **LOCAL CHECKS PASS; exact-commit CI/review pending.**
This is not physical-device readiness.

Baseline: `feature/guided-padel-setup`,
`9fbb37673bebaf607f5f4862ec1909f5124f1fdd`. Scope and acceptance criteria:
[owner-approved correction contract](../design/261023_Playing_Arm_Setup_Correction_v1.0.md).

## Authorship and scope

Inherited Astra implementation agent authored the phone view and matching in-app
guide copy, a DEBUG-only offline saved-handedness fixture, and focused setup UI
tests. Its exact runtime model
identifier/reasoning setting was not independently exposed. Root used non-Astra
verification; a separate non-Astra agent reviewed the frozen source without edits.
The Watch view, model authority, Core, recording, Health, transport, storage schemas,
project/build settings and build number are unchanged.

Xcode 27.0 (27A266a), iOS/watchOS 27 SDKs. Tests use a disposable iPhone 15 Pro
simulator on iOS 27 with isolated temporary directories and disabled connectivity.
Private local evidence directory: `PhysicalReadiness1/O14-ArmSetupUX` under the
existing owner-first DerivedData evidence root. No real readings are published.

## Retained runs

| Run | Result | Meaning |
| --- | --- | --- |
| 01 test build | PASS | New regression tests compile against unchanged production. |
| 03 initial red invocation | Infrastructure failure; no tests executed | Copying the generated runner outside Products changed `__TESTROOT__` resolution. Preserve the failure. |
| 04 runner correction | Same isolated runner bytes placed alongside original Products runner | Fixes the known path error; not an application/source change. |
| 05 red regression | Expected FAIL: 1 method, missing `setupCurrentWrist` | Original UI still exposed duplicate racket-arm/usual-hand choices and lacked the new wrist question. |
| 06 revised test build | PASS | Bounded phone-view and DEBUG-fixture implementation compiles. |
| 08 initial revised UI suite | FAIL: 7 methods, 4 passed / 3 failed, zero skips | Side combinations, consent, offline and re-entry passed. Both native largest-text audits reported heading clipping; the saved-mismatch test could not open a disabled picker. |
| 11 heading/diagnostic test build | PASS | Heading shortened without text-size caps or audit changes; menu failures now retain geometry, status/error, screenshots and hierarchy. |
| 12 corrected-fixture test build | PASS | DEBUG seed now creates coherent protected namespaces through the real bootstrap. |
| 14 correction checks | FAIL: 3 methods, 1 passed / 2 failed, zero skips | Both saved preference/draft paths pass. Portrait flags the decorative eyebrow at largest text. Landscape exceeds the invocation's 180-second default while revealing a static paragraph taller than its usable viewport; the runner's recovery is retained. |
| 16 final-source test build | PASS | Three scoped phone production inputs and focused tests compile. |
| 18 final-source native checks | PASS: 2 methods, zero failures/skips | Largest text, portrait and landscape, including native five-category audits and setup controls/guidance. |
| 20 Source D remaining regressions | FAIL: 5 methods, 4 passed / 1 failed, zero skips | Consent/offline, re-entry/new-left and saved preference/draft corrections pass. The four-pairing method fails because a single tap does not open the current-wrist menu. |
| 23 affected Release build | PASS | Xcode 27 generic iOS, signing disabled; phone and embedded Watch dependency compile. Existing unchanged concurrency and metadata warnings remain; this is not signing/device evidence. |
| 24 Source E test build | PASS | Test-only menu positioning correction; all production inputs remain Source D. |
| 26 Source E affected regressions | PASS: 5 methods, zero failures/skips | All four side pairings; consent/offline; re-entry/new-left; saved preference/draft preservation and explicit correction. One invocation, no retries; 429.270 seconds for the suite. |

The initial revised source identity is retained privately in `06-source-identity.json`.
Initial independent frozen-source review found no source blocker conditional on
runtime results, but missed the fixture's protected-bootstrap dependency. After
the runtime failure, the reviewer independently traced and corrected that diagnosis.
This was not a committed-HEAD G6 verdict. Native accessibility assertions remain
intact; any correction requires affected regression checks and review.

## Failure causes and bounded corrections

The native audits identified the original forced-newline heading, “Review on
iPhone. / Start on Watch.” It was shortened to “Prepare your Watch” with the same
accessible typography. The explicit local Watch Start instruction remains. Actual
audit screenshots/descriptions are retained under `09-failures`; do not replace
them with a claim that the original audit passed.

The DEBUG mismatch fixture created `PracticeSetup-v1` directly before the real
protected bootstrap existed. `OwnerPhoneBootstrap` correctly rejects such a
partial protected namespace. Consequently the model had no loaded stored snapshot
and the new view correctly kept choices disabled. The fix seeds preferences/draft
through `OwnerPhoneBootstrap.withStores` with a checked installation epoch. No
production bootstrap rule, UI assertion, or capture-admission condition was weakened.

The run-14 candidate's 115-input source manifest has SHA-256
`0a671fb88c19adcafbccf654ff09d0afce7d259d5e99bf8cd74b3f571849410f`.
Exactly the two authorized phone/DEBUG files and the focused UI test file differ
from baseline; all Watch/Core/project/workflow inputs remain identical.

Run 20 retained a screenshot, geometry and full hierarchy after the missing menu.
The current-wrist button was at y131.7–166 (tap centre y148.8), while top overlay
nodes extended to y153. The original helper accepted a usable viewport starting
at y121. No menu was visible. Inadequate near-header positioning is established;
the native tap recipient and actual interception are not proven. This does not
establish a production Picker or setup-state defect.

Source E changes only the test driver from Source D: the existing consent-control
centring algorithm is renamed and reused for choice menus. It requires enabled,
full-rectangle containment, hittability and a centre in the viewport's middle
20 percent before a single tap. The 24 positioning limit, five-second option wait,
all scenarios/assertions/audits and failure captures remain intact. There is no
automatic tap/test retry. All attachments are exported under
`22-regression-attachments`; the tool's `--only-failures` export returned an empty
manifest despite the recorded failure, so it is not the attachment authority.

Frozen Source D: [v1.0 input manifest](261023_Playing_Arm_Setup_Code_State_v1.0.sha256),
SHA-256 `350625c9cb794b44057251e19bb3e662b09dc55d3f433d089ebe674c950dd05e`.
Frozen Source E: [v1.1 input manifest](261023_Playing_Arm_Setup_Code_State_v1.1.sha256),
SHA-256 `96fbe31f4273877c3fd51fb830cacdb5ddd6fbffc50c1f68c24de1f2a88d22e2`.
The four changed inputs remain three approved phone files and the UI test file;
all Watch/Core/project/workflow inputs match baseline.

Independent non-Astra source review clears the bounded test correction. It traced
the native-audit call graph: the two run-18 native test paths do not call the
changed choice/consent helper. Their assertions, categories, navigation helpers
and all production inputs are unchanged. Run 18 remains scoped Source D
accessibility evidence, not a claim to have run the final test hash. The five
affected methods passed on Source E in run 26; full exact-HEAD CI still runs all
seven methods. This is not the final committed-HEAD review verdict.

The current checksum index verifies all 115 inputs. Exactly the four permitted
runtime/test paths differ from baseline. Both dated manifests are retained;
the current CI index equals Source E. Scoped `git diff --check` passes. Run 26's
machine-readable summary is retained privately as `27-regression-summary.json`.

## Coverage and current limits

The seven focused methods cover unanswered choices/consent gating; four side
combinations and reset after arm changes; re-entry; first unsaved left handedness;
saved preference/draft mismatches and explicit correction; original consent/offline
behavior; and largest-text portrait/landscape controls. Native five-category audits
run on the initial unanswered screen. Expanded guidance has reachability/geometry
checks, not an exhaustive native audit of every expanded state.

The user-visible phone simulator was updated and launched to Source D. It is a
preview of work in progress. The physical iPhone and Watch retain the previously
installed baseline build 7; no new physical installation or sensor observation
occurred during this correction. No merge or release is authorized or performed.

## Next action

Publish the locally verified bounded patch and obtain exact-commit CI and
independent review. Record commit and later CI/review outcomes on PR #3 without
changing the tested source solely to add its own commit identifier.
Physical-device replacement and sensor validation remain distinct.
