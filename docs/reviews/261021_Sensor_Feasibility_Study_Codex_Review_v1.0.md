# Sensor feasibility study — independent Codex review v1.0

21 October 2026 · Reviewer: GPT-6 Astra, Extra High reasoning · Architecture and feasibility review only

**Verdict: CLEARED FOR OWNER REVIEW. IMPLEMENTATION REMAINS ON HOLD.** No unresolved blocker prevents the owner from reviewing the corrected proposal. This is not implementation approval, a formal G6 code review, a merge verdict, or evidence that the proposed measurements work.

## Exact review identity and scope

- Reviewed [study v1.0](../architecture/261021_Sensor_Feasibility_and_Implementation_Study_v1.0.md), SHA-256 **`3426b30195876cf628d8bcd79cc5728f2cec39a9397fafbe12aeb1fe8e9b7980`**. A later study edit requires review of the change and a new recorded identity.
- Checkout: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch **`feature/guided-padel-setup`**; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; intentional unpublished changes and no upstream. HEAD alone does not identify the reviewed application source.
- Independently verified all **69 source entries** against [combined manifest](../testing/261021_Black_Turquoise_White_AB_Source_v1.0.sha256), SHA-256 `9c69a73bb6031fefd26c82a16ef1ebefadda2c50573e33f7a5725720b4872ff0`; no mismatch.
- Read-only remote reconciliation confirmed main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`, governance `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, recording branch `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, and [PR #2](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/2) still **OPEN/DRAFT** at that recording HEAD. This study is not the contents or approval of that PR.

Reviewed repository governance, current product authority/Gate Card/handover, relevant approved specification sections, the immutable phone-led/guest/statistics plans, and participant v1.2 with its v1.3 package split. Independently inspected current motion/workout/capture/archive/statistics code and relevant installed SDK declarations, then checked current official Apple documentation. Only this review report was authored by the reviewer. No app, test, configuration or study file was modified; no build/test, simulator/device action, personal-data inspection or Git publication was performed.

## Findings and disposition

The first reviewed candidate was `9570a8b2ceb6475e9f2e8b780c9b80bf8373d07fc787cfd4109ed156c1826cd7`. These **P2 planning findings** were sent to the author and resolved in the exact final study above:

| Finding | Resolution checked in final study |
| --- | --- |
| First-build dependencies conflicted: D required history/pedometer although the first owner candidate deferred them; X could be read as requiring every future adapter. | §7 makes D depend on H1/T0/X, explicitly displays absent optional channels, and limits X to the selected candidate's adapters. Later channels require refreshed export/review/cleanup evidence. Optional location no longer suggests a dependency cycle. |
| Withdrawal/local-deletion promises lacked a bounded execution allocation. Existing Delete could otherwise leave new telemetry or derived companions behind while reporting success. | §4 and §7 add W1 before the first owner telemetry candidate and W2 before non-owner collection. Complete local deletion covers companions and derivatives, with active/export/receipt checks, crash recovery and minimal replay/tombstone guards. Paired cleanup remains pending until acknowledged; external exports and unrelated system Health data are outside app deletion. |
| No builder/no saved summary could be mistaken for no Health side effects, particularly when choosing discard versus save. | §5 explicitly distinguishes system-generated Health samples/Activity effects from app-saved workout summaries. Discarding the builder does not promise their erasure; §10 repeats the limit in the proposed default. |
| Workout and participant-policy choices asked the owner to supply policies without concrete recommendations. | §10 now proposes app-local feasibility results without an app-saved workout summary, separate participant purpose/export choices, 90-day guest-content retention and 14-day redacted diagnostics. All remain proposals requiring actual consent/policy approval; they are not recorded approvals. |

**Unresolved blocking findings: none for owner-review readiness.** Concrete package contracts, owner decisions and physical evidence remain prerequisites to execution or capability claims.

## Independent technical conclusions

1. **The current source audit is accurate.** `WatchMotionSource` uses `CMBatchedSensorManager` for separate three-axis acceleration and 13-component fused device-motion records. Fused rotation is not an independent raw-gyro stream. Raw-v1/archive compatibility and the 120-active-second set limit remain intact. The workout driver requests no Health read types and creates no builder; HR, recovery, pedometer, GPS and AI collection are not current capabilities. P1 and existing-motion charts are local completed increments; participant adoption and final phone-led workflow remain unfinished.

2. **“Latest” is correctly separated from “inspected.”** Version-only checks confirmed installed Xcode 27.0 (27A266a) and iOS/watchOS 27.0 SDKs. Apple's [release index](https://developer.apple.com/news/releases/) independently confirms newer released Xcode 27.1 and 27.2 release candidates. The study requires toolchain/device-build reconciliation and affected API checks before implementation. It does not assume parity, authorize updates or require new hardware. New Series 12/Ultra 4 product capabilities are distinguished from public app access; the owner's Ultra 2 remains the first proposed evidence baseline.

3. **The Apple Intelligence correction is essential and supported.** Installed watchOS 27 interfaces expose `PrivateCloudComputeLanguageModel`, while `SystemLanguageModel` remains unavailable on Watch. Apple's [Foundation Models session](https://developer.apple.com/videos/play/wwdc2026/241/) and [watchOS group lab](https://developer.apple.com/videos/play/wwdc2026/8014/) distinguish network inference from local Watch execution or automatic use of the paired iPhone's local model. The proposed iPhone-local explanation path, explicit PCC deferral, runtime/locale/model checks, token limits and deterministic fallback are appropriate. Generation remains outside acquisition and measurement decisions.

4. **Health and shared-Watch boundaries are appropriately conservative.** SDK inspection confirms new RMSSD and workout-zone APIs, but no general acquisition method was found for `CMHighFrequencyHeartRateData`; its existence is not a live-HR driver. OS 27's limited-history authorization is real and does not reveal full-versus-denied read permission. [Apple authorization guidance](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) supports the study's missing-data treatment. Guest capture must not start an owner workout or inherit owner history; stopping old resources needs observed completion and immutable callback attribution. Ordinary-motion wrist-down feasibility and passive watchOS tracking remain separate unresolved physical facts.

5. **The evaluation and package sequence preserve the right limits.** The plan retains approved participant/phone contracts, bounded packages and exact-source review. It separates clock domains, delayed sparse telemetry, cumulative pedometer behavior and qualified GPS estimates. It avoids wrist-to-body-distance integration, precise ball/racket claims and fabricated sampling or accuracy guarantees. Owner-led inspection, blinded repeat labels, held-out sessions and an unchanged-rule matched-mode wife evaluation are proportionate. Self labels and one new player cannot establish general-player measurement validity.

## Decisions and evidence still required

The owner needs to review §10's first court-candidate scope, optional GPS timing, workout save/discard semantics, recovery observation windows, actual non-owner consent/retention policy, and optional iPhone-local AI scope. Confirmed phone-once-per-practice setup, playing-arm placement, guest motion-only investigation and theme choices need no new decision.

Before any affected package, its exact contract must finalize practical duration/storage/queue/lateness limits, consent bindings, permissions and failure acceptance. Review W1 against every component included in the actual candidate; later channels cannot silently inherit cleanup or export proof. Timezone presentation changes must not be treated as changes to Unix time. Pedometer counter resets and delayed cumulative snapshots require explicit tested baseline/deduplication rules.

Physical capture, paired transfer/export, sensor saturation/rates, HR/recovery coverage, shared-Watch resource isolation, indoor/outdoor location usefulness, wrist-down operation and battery cost remain **UNKNOWN**. Prior physical build4 launch evidence and local build6 simulator evidence do not resolve them. No tests were rerun in this planning review.

**Next action:** present the exact study and this review to the owner. Keep all pending implementation on HOLD until the owner approves the concrete direction and the coordinator releases a separately reviewed bounded package.
