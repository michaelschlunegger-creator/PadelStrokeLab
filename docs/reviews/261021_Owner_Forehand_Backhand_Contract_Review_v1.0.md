# Owner forehand/backhand first build — independent contract review v1.0

21 October 2026. Independent Codex review, Astra Extra High role. Review only; no application, test or configuration changes.

**Contract verdict: CLEARED FOR DIRECTOR RATIFICATION AND BOUNDED LOCAL IMPLEMENTATION. No unresolved contract blockers.** The director can release O1 without requesting the already-approved owner direction again. This is an architecture/test-contract clearance, not a formal committed-HEAD G6 review, merge verdict, or proof of physical recording/HR capability.

## Exact review identity

- Reviewed [first-build contract v1.0](../testing/261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md), SHA-256 **`f7666a8d73d5e11fa786571f294b9837d96d3768b30d9318b578ab8d762f706f`**. Freeze this identity; a subsequent change needs affected review.
- Checkout `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch **`feature/guided-padel-setup`**, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, intentional unpublished work and no upstream. HEAD alone does not identify the application source.
- Independently verified all **69 protected source entries** against [combined source manifest](../testing/261021_Black_Turquoise_White_AB_Source_v1.0.sha256), manifest SHA-256 `9c69a73bb6031fefd26c82a16ef1ebefadda2c50573e33f7a5725720b4872ff0`; all matched during review preparation. This contract review does not review subsequent O1 implementation.
- Read-only remote reconciliation confirmed main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`, governance `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, and recording branch `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Local HEAD was 10 commits ahead of, and none behind, `origin/main`. [PR #2](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/2) remains open/draft at the recording HEAD; this contract is not that PR's current content or clearance.

Read repository governance, current product authority/Gate Card/handover, applicable immutable PSL-SPEC-001 v1.1 requirements, phone-led architecture/ratification, participant v1.2 and v1.3 split, and the sensor study with its independent review. Verified the specification, participant contracts, study/review and source-manifest checksums against their recorded identities. Inspected relevant existing workout, admission, archive, annotation and deletion boundaries.

## Focused findings and corrections

The initial reviewed contract was `1c0a91a3b691ce7f9317ec083f7ebb6bffc305ec9339529d434948747e2cf0b9`. The following corrections are checked in the exact final contract:

| Issue | Final disposition |
| --- | --- |
| Clipping a recovery window could produce a +60 result from samples at +50/+54 even when the next set starts at +55. | Standard +60/+120 windows require uninterrupted observation through +70/+130. They remain pending beforehand and become missing if truncated. Whole sample intervals must belong to an eligible observation segment. Exact next-set and interval-crossing regression fixtures are required. |
| Envelope unit and 32-component limit did not accommodate a complete 20-set practice with separate raw/context pairs. | One finalized ended/interrupted practice is the envelope unit: up to 20 sets, 64 components and 256 MiB, using streaming I/O. Existing raw archives include timeline/label snapshots. Pre-finalization transfers remain raw-only; the distinct practice receipt covers exact inventory/revision/digest. Verified interrupted content remains interrupted, and later label edits create a new immutable envelope revision. |
| The legacy `.ownerSelf` label-author field could be read as proof of recording wearer. | Legacy labels remain readable, but neither their author field nor current selection assigns a wearer. Only new records with validated owner contexts qualify as owner-only evidence. |
| Current-practice HR acquisition needed a precise device/source boundary and minimal persisted provenance. | Query restricts dates and the current local Watch; missing/mismatched provenance, user-entered data and out-of-observation intervals are excluded. There is no broader-history fallback. Exact device equality remains runtime-only; persisted provenance excludes custom display names, Apple-account and system-device identifiers. |

## Independent conclusions

The dedicated single-owner namespace is a defensible reduction of the unused multi-participant implementation. No alias, enrollment restoration, slot reassignment, guest collection or role-transfer API is admitted. Explicit owner/device attestation, current consent, monotonic withdrawal/replay barriers and immutable raw-metadata binding remain required. Missing or conflicting state fails closed; future guest work must restore the original multi-participant safeguards through its own reviewed scope.

The contract retains the critical publication-to-Start ordering, durable revision reconciliation, generation fencing, no-suspension final admission, failed-ID nonreuse and observed resource shutdown. End, withdrawal, callback delay and shutdown failure cannot silently create new readiness or reattribute samples. Phone requests remain pending until the Watch actually applies and acknowledges them. Workout recovery and no-phone capture still require implementation and physical proof.

Both manual forehand and backhand are in the first build and owner study. Playing-arm confirmation, clean/mishit/uncertain/non-contact distinctions, separate sessions and blinded repeat labels remain explicit. No automatic recognition, clean-hit accuracy, general-player performance or full-match claim is authorized.

Optional HR has a usable missing-data path and does not infer read authorization from request success or empty results. No app workout summary is saved; the contract correctly preserves the possibility of independent system Health/Activity effects. App deletion cannot promise to erase those effects. Complete app-local deletion covers raw and companion content, staging/caches/exports and replay guards; paired cleanup remains visibly pending until acknowledged. Raw-v1 and existing archive/receipt meanings remain intact.

Version-only checks independently confirmed Xcode 27.0 (27A266a) and both 27.0 SDKs. Installed Watch SDK headers expose local-device/sample-date predicates and `HKDevice.localDevice`. The contract explicitly restricts implementation to inspected APIs and runtime checks, acknowledges newer stable 27.1, and authorizes no toolchain update. Physical Ultra 2 HR matching, cadence and availability are unproved.

## Release boundary

O1 is limited to two new pure owner identity/context production files, at most 1,200 production lines, with the named tests defined first. No filesystem, runtime, transport or UI adoption belongs in O1. Later packages retain independent file/line/risk-domain limits, tests, exact source freezes, local evidence and separate review before the next dependent mutation. Metadata scaffolding alone is not delivery of the requested functional build.

No tests/builds, simulator/device operations, personal-data access, Git mutations or publication were performed by this review. Only this report was written. Formal committed-HEAD review, exact pushed CI, physical evidence, installation and merge/release permissions remain separate gates.

**Next action:** director ratifies this exact contract and releases O1 from the verified 69-entry baseline; continue through the bounded packages to the complete owner-first candidate.
