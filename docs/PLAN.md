# Delivery plan

## Current delivery — 19 October 2026

This section supersedes the historical storage-only/approval-pending statuses below. The owner authorized the complete physical-shot tester and Astra planning first. The [approved implementation plan](architecture/261018_Physical_Shot_Logger_Plan_v1.0.md) preceded bounded capture, Watch lifecycle/controls, annotations/archive/connectivity and phone-review packages. Those runtime paths are now implemented locally on `feature/watch-recording-storage`, based on `ee15c0e`, with no upstream or published logger commit.

Core102 tests, final iPhone7 app-host+9 UI tests and Watch11 app-host+5 UI tests pass, as do both Release simulator builds. Both apps have a signed physical build2 with the required Watch HealthKit profile. The final [52-file source identity](testing/261019_Physical_Logger_Top_Scan_Code_State.sha256) preserves unchanged production/build files and the corrected Watch navigation fixture. See [current evidence](testing/261019_Physical_Logger_Local_Evidence_v1.0.md); failed runs11–13 remain retained.

Both physical devices are now reachable and their signed build2 profiles verified. Next: obtain explicit approval for the prepared [publication proposal](testing/261019_Logger_Publication_Preflight_v1.0.md), run exact-HEAD CI and independent committed-HEAD review, then verify installation separately and follow the [one-set runbook](testing/261019_Physical_Shot_Logger_Runbook_v1.0.md). The two-line CI inventory/base-filter correction is locally validated; no app/runtime files changed. On-court sensor, background, transfer, battery and quality-prediction evidence remain absent. G5/G6 precede physical G7; no merge or release.

The full seven-stage product story below remains the roadmap; no AI/social/booking work has entered this logger. Initial personal feasibility uses the owner's skills and self-reference labels, including uncertain and repeat labels. Optional paid expertise remains separately justified and approved.

Updated 16 October 2026. Authority: [PSL-SPEC-001 v1.1](PRODUCT_AUTHORITY.md).

The approved seven stages are: personal recording tester; contact-signal feasibility; useful personal training companion; validated expansion; social/community foundation; fair challenges/rankings; and coordination/provider integrations. Each stage depends on its own evidence and approved scope.

## Current bounded increment

The preparation foundation supports WP1 without completing it. It covers six production files: package manifest, two shared model/codec sources, two preparation views and Xcode project integration. No sensor, workout, transport, durable session, AI or community implementation is included.

Local metadata tests and simulator builds/suites are recorded in [Testing](TESTING.md). CI, committed-HEAD independent review, relevant physical validation and approved merge remain open.

## Next increment

Define and review the smallest owner recording package before changing capture code. Specify Watch session authority, explicit start/stop states, sensor availability and observed rates, workout/resource ownership, monotonic timing, bounded durable writes, interruption/recovery, data completeness and safe saved-state semantics. Split transfer/export if the package would exceed eight production files, 2,500 changed lines or two Risk Level 3 domains.

The owner supplies a practical clean-contact/mishit rubric distinguishing contact feel from shot outcome and technique. Record timing, confidence and source evidence in the future label format, preserve uncertain/non-contact attempts and allow blinded repeat labels. Start with normal practice and simple signal inspection; formal held-out evaluation criteria are ratified before tuning against evaluation sessions.

Do not turn proposed collection sizes, accuracy thresholds or the older PDF's study assumptions into mandatory personal pilot gates. Any outside expense requires a concrete question and separate approval.

## Open dependencies

- Physical iPhone 15 Pro / Watch Ultra 2 OS builds, pairing, signing/install and capabilities.
- Approved capture architecture and test contract; no sensor evidence yet.
- Exact owner rubric and first short court protocol.
- GitHub is the development source of truth; the active Xcode checkout remains local. See [ADR 002](adr/002-source-of-truth.md).
- Initial foundation publication is owner-authorized; independent exact-HEAD review, clean CI, physical evidence and later merge approval remain open.

## GitHub publication

Foundation implementation commit `7ae8a9855a52251b588e7cc4cb7ab2aa1fd7ebd0` is pushed on `chore/project-governance`; [draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1) is open. Documentation-only follow-ups preserve the tested source manifest. CI, independent exact-HEAD review, physical evidence and owner-approved merge remain open. Source synchronization to Drive is superseded by ADR 002.

## Simulator-first UI review — 17 October 2026

Current presentation increment covers phone Practice, Practice guide, Contact reference, Watch preparation and native arm picker with shared blue/yellow/white styling and appropriate native Liquid Glass controls. See the [design contract](design/261017_Blue_Yellow_White_UI_Contract_v1.0.md). Physical installation is on owner hold until simulator UI review. Capture, AI, community and booking remain future stages. Refresh exact-source builds/tests/review for these changes; earlier foundation evidence is historical.

## Watch motion recording — current next increment, 17 October 2026

Owner completed the manual simulator preparation-UI walkthrough and requested recording. [Proposed plan](architecture/261017_Watch_Motion_Recording_Plan_v1.0.md) and [test contract](testing/261017_Watch_Recording_Test_Contract_v1.0.md) follow Astra Extra High architecture review. Implement the durable recording model/codec/store first; separately bound sensors, workout/permissions and session/concurrency integration. Verified retrieval is required before accepting court collection. No production recording changes yet; high-risk plan and dependent-branch exception await approval. PR1 remains draft/unmerged and its exact-head hosted CI is cancelled. Physical recording remains untested.

### Approved package A implementation

The owner approved the concrete plan and dependent branch with “ok, add the code.” Current branch: `feature/watch-recording-storage`, based on `ee15c0e`. Astra High implemented the three approved recording storage/model/codec files and their tests. The current [evidence](testing/261017_Recording_Storage_Local_Evidence_v1.0.md) records results and limits. Existing practice schemas, all app screens, signing/configuration, permissions and historical evidence remain unchanged. This is local/uncommitted work, not part of draft PR1 yet.

Next delivery gate: obtain authorization for a scoped commit/push/draft PR, update CI's source inventory for the added files in an explicitly bounded publication increment, then obtain current CI and independent committed-HEAD review. No merge or physical install is authorized. Later sensor acquisition/timing, workout/permissions and session/concurrency packages need their own bounded contracts before code; storage work does not complete WP1 or enable court collection.
