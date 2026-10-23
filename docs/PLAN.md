# Current checkpoint — corrected build7 candidate

23 October2026. Branch `feature/guided-padel-setup`, amendment base `e43eb7fb25dc2bcdafca7ab5ca060d3926a96d64`. CI39880508648 failed two Watch terminal-state tests and one phone independent-reader test; all27 phone UI executions passed. The proven clock-boundary production defect and separately verified fixture race are corrected and source-reviewed. [Deadline correction](testing/261023_Practice_Deadline_Correction_v1.0.md); [phone fixture](testing/261023_Phone_Review_Fixture_Isolation_v1.0.md).

Core390/29 and phone app-host74/125 pass, zero failures/skips. Watch test products compile; both Release and fresh signed phone/embeddedWatch version1.0/build7 pass identity/signature/profile checks. Local Watch execution is unavailable due duplicate27 runtime identifiers; full unchanged Watch runtime tests must pass on exact-head CI. No gate is waived. Source11 freezes115inputs, SHA256 `913511f978b91aaccedc8e98c088df545ead81b8fdd9f4ad71d413ea47aa17ec`; exactly six planned source/test/config paths differ from Source9. Old signed build6 is not correction proof.

One next action: publish and complete full exact-head Core/Phone/Watch/foundation plus committed review, then install/verify iPhone and Watch separately. No installation, physical pass, merge or release claimed. PR#3 records later exact-commit outcomes without changing tested HEAD; earlier checkpoints below are historical.

---
# Current checkpoint — mounted runtime validation

23 October2026. Branch `feature/guided-padel-setup`, amendment base `c8cbb67efb35be3be539b1d6bf2392179c29615a`. CI39872894389 passed fullCore388tests but failed first Watch boot on missing runtime-bundle resolution; later builds/app suites were skipped. [Retained outcome and correction](testing/261023_CI_Runtime_Validation_v1.0.md) separate app evidence from runtime preparation failure; its cause remains unproven.

The workflow now validates current mountedOS27 runtime paths/identity before Core, uses fresh inventory after Core and revalidates Watch immediately before first boot. All tests/coverage/assertions/deadlines remain intact; no runtime deletion/download/fallback or boot retry. YAML/Bash/Python and four controlled runtime-guard cases pass; independent source review clears the correction. Source7 manifest SHA256 `eb8a533ebba9de0749676717a8b9cc81865a7905f274cd8772f8891658dfcc8c`; only workflow differs from Source6. App/Core/test/signing evidence retains input identity. Actual remote boot/suite success remains required; no installation or physical pass.

One next action: publish this bounded correction and complete exact-head runtime preparation/CI/review, then install and verify both available devices. PR#3 carries live observations; earlier checkpoints are historical.

---

# Current checkpoint — CI execution mitigation

23 October2026. Branch `feature/guided-padel-setup`, amendment base `cbd6c4fc17ae4456cc106bbfb3abe074d7a0d71e`. Two verified different workers stalled shared-code verification beyond its15-minute limit; both run39864792158 attempts were cancelled and yielded no logs/artifacts. Cause remains UNKNOWN; no app failure is inferred. See [execution evidence and mitigation](testing/261023_CI_Worker_Diagnostics_v1.0.md).

The unchanged Core step now runs before simulator creation, with bounded resource diagnostics and an allowlisted baseline upload before Core. Tests/coverage/assertions/deadlines and every required gate remain intact. YAML/Bash checks and controlled success/failure/monitor-cleanup probes pass; independent source review clears the workflow. Source6 manifest SHA256 `445fd7684ec752b681b28fdd551d6cda0ad214339ed44cf82ff1c4ebb285b94c`; only workflow differs from Source5, preserving all app/Core/signing evidence. The mitigation requires real remote verification. No installation or physical pass is claimed.

One next action: publish this bounded workflow correction and complete exact-head CI/review, then install and verify both available devices. PR#3 carries live observations; earlier checkpoints are historical.

---

# Current checkpoint — final UI driver verification

23 October2026. Branch `feature/guided-padel-setup`, amendment base `a56ebeea51d7395bed9e2b36c77ae02c09105f3c`. CI39847924301 is FAILED evidence: Core and both Release builds passed; exactly one of27 phone UI executions failed in largest-text landscape scrolling, so Watch CI was skipped. The single-file test-driver correction preserves every assertion and40attempts; independent source review clears it and the formerly failing case passes locally. All seven affected Motion UI methods pass across two scoped runs, zero failures/skips (focused landscape1/1 plus six remaining regressions6/6). See [correction/evidence](testing/261023_UI_Scroll_Driver_Correction_v1.0.md).

Only the aggregate CI cap also changes90→120 minutes: measured CI plus the skipped Watch suite exceeds93 minutes. Individual deadlines, complete CI coverage and no-retry policy remain unchanged. Current115-input manifest SHA256 `f374785cdd9784728de4f7d98a8e42c2c9614eb378d3509ef086dd27d1f6849f`. App/Core production and signed-product inputs are unchanged. New exact-head CI/review and separate installations are pending; no physical sensor pass is claimed.

One next action: publish the locally verified bounded correction, then complete exact-head CI/review and install on each available device. Subsequent observations belong on PR#3 and linked evidence. Earlier checkpoints are historical.

---

# Current — Core CI portability verified locally

23 October2026. Full serialized Core388/696 passes; app/Watch source is unchanged and retains all previous passing evidence. See [portability verification](testing/261023_Core_CI_Portability_v1.0.md) for the first failed CI root cause, narrow correction, source identity and justified aggregate job budget. New exact-head CI/review and installation remain pending; no physical performance claim. Earlier checkpoints are historical.

---

# Current next steps — corrected owner-first candidate

22 October 2026, `feature/guided-padel-setup`: the bounded Watch deletion/staging and phone consent-analysis corrections pass local automation and source review. Publish the correction and evidence, finish exact-source CI and committed review, then verify separate iPhone/Watch installation. Follow the controlled dry run before forehand/backhand contact collection. Sensor/background/battery performance and automatic recognition remain unverified. No merge or release authorization.

[Verification](testing/261022_Privacy_Readiness_Corrections_Verification_v1.0.md) · [PR #3](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/3). Earlier checkpoints below are historical.

---

# Current candidate — GitHub publication and device verification

22 October 2026. `feature/guided-padel-setup`, based on `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. The owner explicitly authorizes installing and adding all code/required documentation to GitHub. Publish a stacked draft PR into `feature/watch-recording-storage`; no merge or release.

[Final local verification](testing/261022_Owner_First_Final_Local_Verification_v1.0.md) records portable source identity, full phone93/145 PASS and full Watch123/194 PASS, corrected UI drivers, both Release identities, signed products/profiles and retained failures. [Product](PRODUCT.md), [architecture](ARCHITECTURE.md), [release gates](RELEASE.md) and the physical runbook describe the current scope. Current PR evidence/checks carry final Watch/CI/device results as they arrive. Physical capture is not claimed verified.

One next action: publish the fully locally tested candidate, obtain exact-head CI/committed-source review, then install and verify phone and Watch separately. Device connection is being established; no installed/physical-capture claim. Earlier checkpoints below remain historical.

---
# Current delivery checkpoint — O8b accepted locally, 22 October 2026

O7 and O8a/O8b local packages are accepted. [O8b verification](testing/261022_Owner_First_O8b_Local_Verification_v1.0.md) records exact105inputs/637delta, focused18/26, full Core373/668, Watch105/172, phone56/101 and both OS27 Simulator Releases. Separate Sol accepted final actual evidence. All work remains unpublished on `feature/guided-padel-setup`.

Continue O9 complete deletion, O10 phone results, then O11 integrated/default-path/UI verification under approved bounds. O9 tests-only active; concrete deletion/tombstone recovery prerequisite is reviewed before production. Preserve failures/default incident46. Current CI/committed-HEAD review, signing, Git publication and owner-approved physical installation remain later gates. Physical testing NOT READY. Earlier status below is historical.

---

# Delivery plan

## 22 October 2026 — O6 accepted locally; motion closure next

Root accepts independent Sol's local **SAFE WITH NON-BLOCKING NOTES** O6 verdict after full Core346methods/613runs (explicit serialized scheduling), current phone/Watch host suites, both Release builds and final guard. [Evidence](testing/261022_Owner_First_O6_Local_Verification_v1.0.md). Preserve default parallel failure17 and incident46; neither was erased.

Next is [O7p motion-source closure](testing/261022_Owner_First_O7_Motion_Closure_Prerequisite_v1.0.md), tests first, then [O7 live practice/HR](testing/261022_Owner_First_O7_Practice_Lifecycle_Execution_v1.0.md). Whole-practice transfer/export/deletion, phone review and O11 final integration follow under existing bounded packages. O11 must explicitly serialize Core testing in CI. Physical testing remains NOT READY; no installation or publication occurred. Older status below is historical.

## 21 October 2026 — corrected O4q accepted locally

The End-ID bypass and separately measured receipt/cancellation fixture blockers are resolved in the frozen [v1.1 checkpoint](testing/261021_Owner_First_O4q_Local_Evidence_v1.1.md), independently [cleared by Sol High](reviews/261021_Owner_First_O4q_Review_v1.1.md) and accepted by root. Core267/20, isolated app-host29/4, strict protected-entry guard and both OS27 Release builds pass; source82/78 unchanged predecessors and266 evidence hashes verified. Prior failed evidence remains immutable.

Next is the separately bounded O4b phone-adoption release; it has not started. Then complete Watch admission, owner HR/recovery, whole-practice delivery/export/deletion, phone results and integrated verification. No Git publication, physical installation, G5/formalG6/G7 or on-court readiness follows from this local correction. Earlier checkpoint status below is history.

**Current blocker:** O4q is written/frozen but not accepted. Focused47/2 passes; full core04 FAILED260/20 with1 unresolved10-second receipt-wait timeout in the existing import/delete test. No retry. Non-Astra implementation review found an End/wire UUID alias path requiring an Astra foundational fix and regressions. Astra's worker hit its usage limit; the owner now reserves Astra for coding only and requires non-Astra for support/review. [Evidence](testing/261021_Owner_First_O4q_Local_Evidence_v1.0.md) and [Gate Card](../GATE_CARD.md) govern continuation. Do not start O4b or claim physical readiness. The release paragraph below records the permitted scope, not completed acceptance.

Active release: **O4q lifecycle prerequisite**, after its sealed [planning-review report](reviews/261021_Owner_First_O4q_Prerequisite_Review_v1.0.md), SHA `6ad92f41a639697cd991430e569db79dec9032ce5a8fbb2206ef352ed4ee6e64`, and director ratification. Tests-first implementation is released. Root ratifies [exact amendment](testing/261021_Owner_First_O4q_Lifecycle_Amendment_v1.0.md) `d46c098f1387442ee669fa8a629927fa5b70d420be913be1888bfa16fef74eb6`: existing channel source/tests only, 200-line cap; later O4b explicitly reduced to 1,240, combined 1,700 retained. Persist distinct practice/setup identities and pending End in the existing journal before dispatch; maintain explicit resolution, privacy fences, canonical compatibility and real capacity checks. Full core/affected isolated app-host tests, both Release builds, source/evidence freeze and independent review/root acceptance precede O4b. No new product scope, publication or physical installation. The checkpoint below describes the accepted predecessor.

Current: **O4a bootstrap accepted locally**, with 82 exact source inputs, 80 unchanged predecessors, independent review, both Release builds and the controlled29-test/4-suite isolated run. Preserve the earlier30-test functional pass and failed default-container guard separately. See [evidence](testing/261021_Owner_First_O4a_Local_Evidence_v1.0.md) and [review](reviews/261021_Owner_First_O4a_Review_v1.0.md). The owner explicitly chose to continue the full approved build until the usage limit. Next is the smallest reviewed O4b lifecycle prerequisite for durable End during pending/dispatched work and distinct practice/setup identities, then phone setup; no new source scope is implied before ratification. Watch admission, HR/recovery, complete delivery/deletion, phone results and integrated tests remain. [Gate Card](../GATE_CARD.md) supersedes historical paragraphs below; no publication or physical replacement.

Latest: O4p accepted locally after verified80-input freeze, focused15/1 and full245/19 tests, both Release builds and independent [review](reviews/261021_Owner_First_O4p_Review_v1.0.md). Only O4a bootstrap is active: new phone OwnerPhoneBootstrap.swift250-line cap and matching app-host tests, all80 predecessors frozen. It uses the new checked P1 API plus checked O3b ownership to implement the deny-only external first-use witness. Relevant app-host regressions/both Release/source review/root acceptance precede O4b. Concrete independent-ID/current-versus-next/relaunch/End proof remains an O4b gate; original combined1,700 budget retained. [Gate Card](../GATE_CARD.md) supersedes historical release paragraphs below. No publication or physical replacement.

Current release supersedes the older O4 paragraph below: only O4p is active under independently reviewed/director-ratified [O4 sequencing amendment](testing/261021_Owner_First_O4_Sequencing_Amendment_v1.0.md), SHA `e58ca5466a7d95dc367415106f0f8a0310eac71643afd75d699456c407314867`. It adds a read-only checked P1 snapshot API in at most10 changed production lines plus existing store tests. Its full core/both Release/freeze/review/acceptance precede O4a deny-only bootstrap250, then O4b original phone UI paths1,440; combined original1,700 preserved. Separate practice/preparation identities are mandatory; O4b concrete lifecycle/relaunch/End proof remains held. All80 accepted O3c inputs were reverified unchanged at release. [Gate Card](../GATE_CARD.md) and [review](reviews/261021_Owner_First_O4_Sequencing_Review_v1.0.md) record scope and withdrawn draft identity clearance. No publication or physical replacement.

Latest execution checkpoint: O3c is locally accepted after separate Astra Extra High review and root verification of80 inputs,78 unchanged predecessors,416 changed production lines,242 core tests/19 suites and both OS27 Release builds. [Evidence](testing/261021_Owner_First_O3c_Local_Evidence_v1.0.md) and [review](reviews/261021_Owner_First_O3c_Review_v1.0.md) preserve final source/evidence and failed06 with its test-scheduling correction. Only O4 phone setup is released: two new/five total named phone production paths,1,700 changed-line cap, phone app-host/UI tests, sole shared connectivity and non-main serialized authority work. Core/Watch/configuration remain frozen. Watch admission, HR/recovery, complete delivery/deletion and phone review remain subsequent packages. [Gate Card](../GATE_CARD.md) records exact current release and coordinated synthetic simulator boundaries. No Git publication or physical replacement has occurred; older O3 checkpoints below are historical.

## Approved execution — forehand and backhand first build, 21 October2026

Owner approved the narrower four-step recommendation and first-build implementation with **both forehand and backhand**. Step1 is phone-led setup, fresh playing-arm/fit confirmation, wrist motion, owner HR/recovery, phone charts and verified transfer/export/complete deletion. Step2 is a physical no-ball workflow/integrity/background/battery check; step3 is owner-labelled forehand/backhand across separate sessions; step4 expands other strokes, movement/GPS, guests, AI and TestFlight through later evidence gates. This supersedes the planning-only hold below for the focused candidate, not the whole study's roadmap. [Execution contract](testing/261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md) and independent technical challenge precede source edits; Astra Extra High implements bounded sequential packages. No new publication, merge, release or guest-collection approval is inferred.

Current execution: O1 owner identity/context and O2 exclusive persistence are accepted locally after separate Astra Extra High review. [O2 source](testing/261021_Owner_First_O2_Source_v1.0.sha256) has75 unchanged-or-added inputs, SHA `29440c97a96b96eb70faf99c072f508a5b62f433f2f102f05ce0ab675e2265f9`; final179 core tests/16 suites and both OS27 Release builds pass. [O2 review](reviews/261021_Owner_First_O2_Review_v1.0.md) has no remaining local blocker. O3 setup wire/channel and sole-delegate asynchronous dispatch are now released under the fixed three-file/1,900-line cap. Phone UI, Watch admission, HR/recovery, full-practice transfer/deletion and phone results remain subsequent bounded packages, not completed capabilities. [Gate Card](../GATE_CARD.md) records exact evidence and current release. The provisional [physical runbook](testing/261021_Owner_Forehand_Backhand_Physical_Runbook_v1.0.md) is reconciled at O11 before use.

O3's original scope/cap is superseded by the independently cleared/director-ratified [sequencing amendment](testing/261021_Owner_First_O3_Sequencing_Amendment_v1.0.md), SHA `b64a693e8ce56054cdb80890bb838fa06ba4970c6afd390e69277f7fade957eb`. Single Watch authority ordering and crash-safe exact-transition mirroring require three bounded packages: O3a pure wire values≤750 lines, O3b durable setup channel≤950 and O3c transport≤600 changed lines. Only O3a is currently released. Its separate source/tests/evidence/review precede O3b; no blanket release of all source follows from this technical amendment.

O3a is now locally accepted: source77 SHA `2eeb0d1107418a3eff3e95ee20150b46e42a9ed3cd1098e0cdeb4c078a95e96b`, all75 predecessors unchanged,192 core tests/17 suites and both Release builds passed, independent review no remaining blocker. O3b's single new durable setup-channel file≤950 lines and matching tests are released; O3c and app integration remain dependent work. This checkpoint supersedes the earlier O3a-only release above.

## Previous 21 October 2026 planning checkpoint — superseded by approved execution above

The owner's latest instruction is **planning first**: Astra Extra High sensor feasibility/implementation study, a separate independent Codex review, then owner review before coding. The study includes latest Apple Watch hardware, iOS/watchOS 27 public APIs and Apple Intelligence. New participant/setup/sensor/Health/location/AI implementation is held. [Study](architecture/261021_Sensor_Feasibility_and_Implementation_Study_v1.0.md) and [review](reviews/261021_Sensor_Feasibility_Study_Codex_Review_v1.0.md) are planning deliverables; no source, test, build or device work is authorized by this checkpoint.

Both deliverables are complete locally. Final study SHA `3426b301…9b7980`; independent review SHA `7f2bb0f9…a127af`, verdict **CLEARED FOR OWNER REVIEW; IMPLEMENTATION REMAINS ON HOLD**. Four planning findings were resolved, including first-owner-build deletion of all new companion data. Owner review of study §10 is the next action; current-source CI, G6 and physical gates are separate. Reconcile installed Xcode27.0 against released27.1 and any deliberately selected27.2RC before future implementation.

Local black/turquoise/white Theme A+B is accepted with independent review and verified simulator builds/presentation/restoration. The [combined69-entry baseline](testing/261021_Black_Turquoise_White_AB_Source_v1.0.sha256) is `9c69a73b…72ff0` on unpublished `feature/guided-padel-setup` at HEAD `bc5e73d`. No physical replacement or Git publication occurred.

After approval of the new study: reconcile participant A models/registry, participant context/store B under the v1.3 split, integrated phone-led setup, and separately bounded owner Health/recovery/steps/GPS and motion-only guest acquisition against the reviewed sequence. The richer features and automatic shot classification remain unfinished. Preserve immutable participant provenance and owner-only Health context. The [Gate Card](../GATE_CARD.md) and [handover](HANDOVER.md) record current evidence and limits. Earlier checkpoints below are historical.


## Latest expanded scope — 20 October 2026

This section supersedes earlier pending-unlock/wizard-next-action text. Padel Master branding/accessibility is a verified interim baseline; phone-led P1 messages/store passed 128 core tests, both OS27 Release builds and independent working-tree source review. The integrated phone setup is unfinished. The owner requests richer statistics and Training-only participant isolation before shot collection: wrist motion, HR/recovery, steps/speed/distance, explicit optional GPS, local Player1/2/3 and a future 5–10-player TestFlight reference cohort. Proposed bounded sequence and measurement limits are in [Reference Training and Statistics v1.0](architecture/261020_Reference_Training_and_Statistics_Plan_v1.0.md).

The owner chose investigation of motion-only guest capture on the shared Watch, acknowledging different sampling/background limits and passive watchOS Health effects. Every guest's app recordings/labels/stats/exports must remain separate; owner Health history cannot substitute for missing guest channels. Participant/setup binding, label provenance, archive compatibility and consent must precede new collection. Existing-motion charts can progress independently of new sensor permissions. Rule-based recognition starts with owner data and separate held-out sessions/players; no validated automatic counts exist yet. No request for shot collection, TestFlight upload, publication, installation, merge or release is made now.

Architecture and focused contracts have passed separate Astra Extra High challenge. Existing-motion statistics source19 is implemented and reviewed, with full final UI/evidence reconciliation in progress; see [evidence](testing/261020_Motion_Statistics_A_Local_Evidence_v1.0.md). After its exact frozen baseline is accepted, proceed with participant A (pure immutable policy/registry) and then B (mandatory recording binding/persistence) under the [ratified v1.3 split](testing/261020_Training_Participants_Package_Split_Amendment_v1.3.md). Each package needs its own exact-source review, tests/builds and baseline handoff. Then amend setup wire2 before transport/UI integration. Preserve all historical failures. No new hardware/guest workflow is ready yet.

## Guided padel setup — current 20 October 2026

Wizard implementation/local automation are complete on `feature/guided-padel-setup`, base `bc5e73d`; final manifest `208bc67b2f6017358ef13a559a6359a24f02bb7ab0159b8f9e45020a787b28b3`. Both complete platform UI suites, model/core regression, Release builds and signed build 5 verification pass. Astra independently checked source, assertion preservation, trigger amendment and conditional first-set runbook. Failed evidence remains visible; no automatic quality scoring or physical capture is claimed.

Next: request publication/conditional-installation approval using the genuine simulator captures, then exact-HEAD CI and fresh committed-source review before any authorized build 5 physical replacement. Live simulator foregrounding also awaits owner unlock. Observe dry-run capture, verified phone transfer/export and separate recovery paths before court collection. Baseline build 4 installation/launch is recorded in [checkpoint](testing/261020_Build4_Installation_Checkpoint_v1.0.md); code and sensor evidence are distinct. No merge or release authorization.

Following dated entries retain historical context.

## Complete-training increment — current 19 October2026

The owner approved the [v1.1 broader-training plan](architecture/261019_Broader_Training_Readiness_Plan_v1.1.md) and all recording workflows with manually selected padel shot types. Astra High implemented the expansion after Astra Extra High architecture review. Earlier draft/pending/forehand-only checkpoints below are historical. No automatic classification, quality scoring or physical success is claimed.

Current next steps: publish the fully locally verified source manifestea180bde under the existing approved draft-PR cycle, obtain exact-HEAD CI and independent Astra review, then install and observe the real-device dry run. Core/app-host/Watch UI/build checks have passed. The bounded deterministic lease-test correction is complete; screenshot cropping was isolated to the collector with no production layout change. Owner setup confirmations arrived and both devices' development tunnels/DDI were reachable. No merge/release approval exists. See [Gate Card](../GATE_CARD.md).

## Review-fix checkpoint — 19 October 2026

The frozen correction source is identified by the [53-file review-fix manifest](testing/261019_Physical_Logger_Review_Fix_Code_State.sha256), SHA256 `b9c70fa757663b4a667341c84e63b0bb8b9bc4c5535d6d739a5eff8a41b79be6`. [Current evidence](testing/261019_Logger_Review_Fix_Evidence_v1.0.md) records core105, both Release builds, Watch19 app-host+5 UI executions and signed build3 passing. Phone7 app-host+9 UI regression also passed without failures. The prior hosted run exceeded45 minutes and was cancelled; fresh exact-HEAD CI/review remain open. No physical install/capture or merge/release occurred.

The owner requests complete first-training readiness before installation and clarified broader workflows than forehand only. [Broader training plan](architecture/261019_Broader_Training_Readiness_Plan_v1.0.md) is a draft pending scope confirmation/approval; it is not implemented by this correction. Current metadata still identifies a forehand drill. Keep the complete setup/capture/pause/resume/save/recovery/transfer/review/labels/export/deletion acceptance map explicit.


Publication update19 October2026: owner approved the exact prepared proposal; implementation commit `2c05afc0419b5221726705240cd1f18f45e3a982` is verified pushed on `feature/watch-recording-storage`. [Publication record](testing/261019_Logger_GitHub_Publication_v1.0.md) supersedes approval-pending/unpublished statuses below. Next: attach the stacked draft PR and obtain clean current CI/new independent committed-HEAD review before physical testing. No merge/release.

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
