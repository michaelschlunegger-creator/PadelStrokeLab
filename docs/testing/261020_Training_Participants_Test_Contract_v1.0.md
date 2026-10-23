# Training participants and immutable recording context — proposed contract v1.0

20 October 2026, Asia/Dubai. Author: GPT-6 Astra, Extra High reasoning.

**Status: PENDING independent clearance and project-director ratification. No tests or production implementation are authorized by this document alone.** The director has preliminarily accepted the bounded scope, identity direction, engineering caps and metadata-only publication approach below. This document records the proposed focused architecture and tests for review.

The separate existing-motion statistics package is in progress. **Reconcile and freeze its final source baseline before creating participant tests or production files.** Do not transfer its evidence, or the earlier P1 evidence, to a changed source state. No UI, Git publication, installation, release or third-party collection is authorized here.

## 1. Authority and baseline gate

Read `AGENTS.md`, `ENGINEERING_GOVERNANCE.md`, `docs/PRODUCT_AUTHORITY.md` and `GATE_CARD.md` at implementation startup. Applicable product authority is immutable PSL-SPEC-001 v1.1, especially §§6.3, 7, 16–18, with the owner's dated participant, guest-isolation, phone-led setup and TestFlight amendments.

The independently reviewed [Reference Training and statistics plan v1.0](../architecture/261020_Reference_Training_and_Statistics_Plan_v1.0.md) has SHA-256 `f7c01e155b2e466afb57195c4877402aa2c1c9a5b95ac317d17d639796fc4f06`. Its review does not replace this package's focused independent clearance.

Planning checkout: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, with intentional unpublished changes. P1's preserved 64-entry checkpoint is `ca4332e66eaf46077a99df949d1d9d0d20895917c02af21db0fce24b64b15171`; it predates the in-progress statistics package and contains no participant implementation.

Before source changes, reverify repository, branch, HEAD, upstream/remotes, PR state, changed-file ownership, exact statistics freeze and applicable evidence. Reverify Xcode 27 and both OS 27 SDKs. Every Swift/Xcode command uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Record the resulting baseline in this package's new implementation evidence; preserve this reviewed proposal unchanged.

## 2. Purpose, boundaries and approved user direction

Provide pure, testable participant/enrollment types and bounded persistence for immutable reference-recording provenance. This package does not acquire data or connect new functionality to either app.

The iPhone remains the main setup/statistics terminal. Phone setup occurs once per practice; Watch shows the selected player and requires fresh physical confirmation and explicit Start each set. Selected participant remains until deliberately changed. This package stores preferences only and cannot grant preparation or Start authority.

Player 1/2/3 belongs only to development Training/reference collection. Ordinary consumer play must not expose a research participant selector or require teaching/configuring strokes. Three local slots are not the 5–10-player trial's cohort limit. Prefer participants' own paired devices for full measurement.

The owner's profile/Health context may be used only when he is the wearer. Guest readings must remain assigned to that guest. The owner has already selected investigation of a separate motion-only guest mode, with no app-initiated Health workout or owner-history reads. Do not reopen that choice or the setup cadence. This package does not implement that acquisition path, promise equivalent sampling, or control watchOS's independent passive Health tracking.

## 3. Allowed package and limits

Two Level 3 domains: **participant/context identity and provenance**, and **bounded local persistence**.

| Purpose | Allowed new files | Planning size |
| --- | --- | --- |
| Participant types and enrollment | `Packages/PadelCore/Sources/PadelCore/TrainingParticipant.swift` | Approximately 280 production lines |
| Immutable context and codec | `Packages/PadelCore/Sources/PadelCore/TrainingRecordingContext.swift` | Approximately 300 production lines |
| Registry/context persistence | `Packages/PadelCore/Sources/PadelCore/TrainingParticipantStore.swift` | Approximately 500 production lines |
| Tests | Corresponding new `TrainingParticipantTests.swift`, `TrainingRecordingContextTests.swift`, `TrainingParticipantStoreTests.swift` under `Packages/PadelCore/Tests/PadelCoreTests/` | Not production |
| Contract/evidence | This proposal; later focused evidence and a new immutable source manifest | Documentation only |

**Hard cap: three new production files and 1,200 production lines.** Approximately 1,080 lines is a planning estimate, not an observed implementation count. Split and re-ratify if the cap cannot be met without weakening correctness. Existing test fixtures/helpers may be reused without editing them.

No `RecordingPaths.swift` change is needed: the caller supplies an existing canonical app-support base for the new namespace.

Forbidden in this package: edits to existing production/test sources, P1 setup messages/store, motion-statistics files, raw recording schema or storage, capture engine/hardware/workout ownership, transport, phone/Watch UI, current labels, archive/import/export/receipt/deletion behavior, permissions/signing/project/workflow configuration, dependencies, cloud/accounts and automatic grouping/classification/analytics. No real participant data is needed.

## 4. Stable identity and explicit enrollment

The canonical subject key is `(studyID: UUID, participantID: UUID)`. Installation IDs, slot numbers, names and display aliases are different facts and cannot substitute for this key.

- A study coordinator issues a study enrollment with a stable participant ID for the person. Explicit transfer/restore of that enrollment preserves study/participant IDs across installations and reinstall. The new installation receives its own local installation epoch.
- A bounded canonical enrollment packet contains schema version, study/participant/enrollment IDs, issuing-authority/installation reference, issuance time and protocol reference. It excludes names, email addresses, Apple/Health identity and secrets.
- Packet integrity is not proof of human identity. Import requires an explicit reviewed-enrollment acknowledgement referencing the packet and its source. No automatic enrollment from a matching name, slot or nearby device.
- Identical enrollment import is idempotent. Conflicting assignments for an existing enrollment or participant identity fail closed. An enrollment from another study remains a different subject key.
- A locally created provisional identity remains marked provisional. Reinstall without the prior enrollment must not silently manufacture a new supposedly independent study player. Unresolved or conflicting identity cannot establish novel-player holdout evidence.
- Local Player 1/2/3 slots point to participant keys. Optional local display aliases are bounded presentation data and excluded from enrollment/context exports. Slot reassignment cannot change historical contexts.
- Persist selected participant independently from the slot pointer. Reassigning a slot must not silently select its new participant. Selection changes are preferences, not accepted Watch preparation.

An explicit same-person alias record may link mistakenly issued participant IDs within one study. Preserve original subject IDs in every context. Require reviewed acknowledgement; reject cycles, conflicting targets, cross-study links and inference from names/slots. Use a direct canonical target rather than unbounded chains.

Enrollment/alias changes advance a monotonically versioned identity-resolution record/digest. Expose records and that revision for later reviewed analysis; **do not implement automatic dataset grouping, holdout allocation or analytics here**. A newly discovered same-person link invalidates earlier assumptions that those IDs represented independent players. Cross-study pooling requires a separate identity policy.

## 5. Consent, account-owner role and acquisition policy

Consent references must identify actual information, protocol and retention-policy versions/digests. Include the consent-record ID/revision/digest, subject, recorded decision/time and explicit purpose scopes. There is no default consent and no fabricated record of a participant agreeing.

Collection, research/model use, private export and optional Health/location scopes remain explicit. Health/location scopes are not implied by collection consent. A context requires granted collection scope matching its actual protocol and subject. Unknown, declined, withdrawn, conflicting or wrong-subject consent cannot authorize a new context for collection.

Actual participant information/consent text, the retention duration and withdrawal process remain unresolved and must be approved before third-party collection. A policy reference is not a substitute for that real process. TestFlight installation is not research consent. Synthetic test consent must be labelled synthetic.

The registry's device-account-owner subject binding requires explicit wearer/owner attestation. **Never infer owner status from Player 1, installation ownership or the currently selected slot.** Do not collect an Apple account identifier. Keep another participant's owner identity out of a guest's exported context.

Acquisition policy is frozen with the subject:

- Owner-workout/owner-history policy is permitted only for an explicitly attested account-owner wearer, with the relevant actual consent.
- A guest policy prohibits app Health workout and owner-history access. It records the intended non-workout motion policy and declared capability, not a claim that the candidate acquisition path works.
- Changing participant or acquisition policy later requires retiring preparation authority and closing the prior participant's observation/recovery resources before new Start. This package supplies metadata constraints only; lifecycle/resource enforcement belongs to later integration.

A historical context records the consent/protocol applicable at collection; it is not perpetual authorization for future use. The latest registry decision must be consulted by later collection/export/withdrawal flows. This package implements neither remote consent nor deletion/withdrawal execution.

## 6. Immutable recording context

`TrainingRecordingContext` schema version 1 is a companion record for `referenceTraining`, separate from raw recording schema version 1. Its creation/publication does not imply that capture happened.

Freeze these fields before samples:

- Recording ID and SHA-256 of the **exact canonical raw `metadata.json` bytes**, using the existing validated metadata encoder and SHA helper.
- Study/participant/enrollment identity and reference-collection mode.
- Collection-session ID supplied by the future **per-participant practice controller**, retained across that participant's sets. Never generate a new session ID automatically for every recording or reuse a setup revision as the session ID.
- Participant-aware setup wire version, preparation identity/revision/digest, phone origin installation epoch, and both Watch runtime/preparation generations.
- Exact consent, information, research protocol and retention-policy references/scopes.
- Acquisition policy, explicit owner/guest relationship attestation, declared capability/source mode and phone/Watch installation provenance.
- Actual playing arm, usual hand, Watch wrist/crown, device/OS/build and protocol details, checked against the raw metadata where represented there.

Use `PlayingArm` and existing metadata types where compatible. Canonical encoding covers all context fields. The capability declaration is a pre-start observation/declaration, not an achieved sample rate or later data-quality result. Preserve the difference.

Setup provenance explicitly targets the forthcoming **participant-aware wire version 2**. P1 wire version 1 did not bind a participant. This package validates typed reference structure and consistency; a later wire/channel package must prove that the full accepted payload's canonical digest includes subject/mode/consent/acquisition policy. It cannot be fabricated from a P1 acknowledgement.

The context subject and the reference-label author are separate facts. Do not overload `.ownerSelf`. Versioned participant-self/observer labels, actual event timing/uncertainty and export compatibility are later packages. Manual intended drill remains manual intent, never a detected shot class.

Historical recordings without context stay participant-not-recorded/unassigned. Current UI selection must never supply their missing identity. Supplementary attestations, if later justified by evidence, require a separate dated mechanism and cannot rewrite originals.

## 7. Proposed API boundary

Concrete names may be refined during independent review, but responsibilities remain bounded:

- Value types: `TrainingParticipantKey`, `TrainingEnrollment`, `TrainingLocalSlot`, `TrainingIdentityAlias`, `TrainingConsentReference`, `TrainingSubjectBinding`, `TrainingAcquisitionPolicy`, `TrainingPreparationProvenance`, `TrainingRecordingContext`, `TrainingContextPublication`.
- `TrainingParticipantStore` opens one exclusively owned namespace and exposes immutable snapshots/exact-key lookup.
- `enroll(_:reviewedAcknowledgement:)`, `assignSlot(_:to:)`, `selectParticipant(_:)`, `registerAlias(_:reviewedAcknowledgement:)` and `recordConsent(_:)` make explicit bounded registry changes.
- `publishContext(_:expectedRegistryRevision:)` validates the current exact subject, consent, acquisition/owner policy and registry revision before durable publication.
- `readContext(recordingID:)` and `validateBinding(context:exactRawMetadataBytes:)` inspect context and metadata binding without claiming complete capture or research-bundle verification.

No method starts recording, grants physical consent, switches the Health account, acquires sensors, invents an acknowledgement, imports raw recordings, assigns old labels, computes a dataset split or issues a verified research receipt. Enrollment import is explicit identity restoration; recording-bundle import is outside scope.

## 8. Bounded persistence and integrity

Use a dedicated `TrainingReference-v1` sibling of `Recordings` and `PracticeSetup-v1` under the caller's existing canonical app-support base. Keep generated artifacts outside synced project/source directories.

Proposed engineering caps, preliminarily accepted by the director:

| Item | Limit |
| --- | --- |
| Registry encoded bytes | 64 KiB |
| Enrolled/provisional subjects | 64 |
| Explicit same-person aliases | 64 |
| Local convenience slots | 3 |
| Context directories, including failed/partial attempts | 512 |
| Encoded context bytes | 8 KiB each |

Apply byte and entry caps together; reaching either fails explicitly. These local storage limits are not claims about cohort size, recording duration or supported measurement performance.

Use descriptor-relative no-follow access, validated names, a single exclusive store owner, bounded canonical checksummed registry replacement and immutable context publication. Validate file type/link count and namespace/ownership identity. Reject symlink/hardlink/path drift, conflicting content, unsupported versions/fields, non-finite values, invalid IDs/revisions/digests and oversized input.

An existing namespace with missing/corrupt registry fails closed; never silently reset enrollment or select an owner. Whole-namespace deletion cannot prove whether this was a new installation or erased state: enrollment restoration must be explicit, and unresolved new identity remains provisional.

Context files are write-once per recording ID. Exact duplicate content is idempotent for storage/inspection only. Conflicting content cannot replace the original. Partial/failed context directories remain bounded evidence and the recording ID cannot be reused for capture. Do not automatically promote interrupted temporary content into a valid context.

A registry mutation cannot rewrite any immutable context. Slot, alias, consent or display changes cannot reassign existing samples. No method writes into existing raw recording directories.

## 9. Pre-start transaction and crash semantics

This package supplies types/store behavior; the following sequence is a contract for the later Watch Start integration:

1. On the live recorder actor, freeze a fresh recording ID, exact validated raw metadata and exact participant-aware accepted setup.
2. On the exclusive store owner, require the caller's expected registry revision and exact current subject, consent and acquisition policy. Atomically publish and synchronize the immutable context before returning local publication proof.
3. Back on the recorder actor, recheck both setup generations, cancellation, wearer/configuration/capability and previous participant resource-shutdown acknowledgement. Only then create the raw writer from the exact bound metadata and admit samples.

There is **no claimed atomic transaction across context and existing raw directories**. The later integration must enforce this ordering and revalidation without blocking the main actor on file I/O.

Failure before completed publication returns no success. Failure after atomic visibility but before synchronization/return may leave a whole context but still returns failure. Cancellation, context-only publication or raw-writer creation failure leaves an orphan context, not a recording. Crash after raw creation is assessed under existing raw interrupted-recording semantics. Preserve failed IDs; create a fresh recording ID for a new Start.

`TrainingContextPublication` means only that local context metadata was durably published. It is not permission to Start, proof of samples, a complete-recording result or a verified research receipt. Reading an identical context after relaunch cannot restore preparation/consent or resume capture.

Existing `PSLReceipt1` and raw archive-v1 verification remain limited to their existing raw/timeline/label components. A later outer research bundle or deliberate archive evolution must verify every included participant/context/label/telemetry component separately. Never silently drop provenance for an older peer or call raw-only verification a verified research transfer.

## 10. Tests defined before production

All fixtures are synthetic. Create the new tests only after this contract is cleared/ratified and the statistics source is frozen. Preserve the expected initial missing-type compile failure and every later failure; no automatic retries, assertion weakening or hidden resets.

1. **Literal schemas:** independent expected canonical enrollment/context bytes and digests; round trips; versions, finite vocabularies, IDs, revisions, required references and byte limits. Reject unknown/extra/conflicting fields and noncanonical representations.
2. **Enrollment restoration:** second installation/reinstall with reviewed enrollment preserves subject/study IDs while installation epoch differs. Repeated identical import is idempotent; conflicting enrollment/subject assignments fail. Missing enrollment cannot silently create an enrolled independent player.
3. **Slots and selection:** all three slots, reuse and optional alias changes preserve existing context bytes. Slot reassignment cannot silently change selected identity. No merge by slot/name; selected subject persists through valid reopen.
4. **Explicit aliases:** direct same-study linkage only; reject cycles, conflicting targets and cross-study links. Identity-resolution revision/digest changes while original contexts remain unchanged. No analytics/group allocation occurs.
5. **Unknown provenance:** missing context, provisional or conflicting identity remains explicitly unresolved/unassigned; lookup never substitutes current selection or owner.
6. **Consent/owner constraints:** absent, withdrawn, wrong-subject, wrong-protocol and stale-consent references reject new publication. Owner role is not inferred from Player 1. Guest-workout/owner-history policy is rejected; unsupported guest acquisition is not reported as operational.
7. **Frozen binding:** reject recording ID, exact raw-metadata SHA, subject, setup version/generations, registry revision, arm/orientation and acquisition-policy inconsistencies. All copied raw metadata remains byte-identical.
8. **Immutability:** exact duplicate context is storage-idempotent; conflicting write for the same recording ID fails without altering the original. Existing/partial context cannot authorize capture or ID reuse.
9. **Crash boundaries:** inject failures around directory creation, temporary write, file synchronization, publication and directory synchronization. Reopen distinguishes valid context, orphan and partial/corrupt state without fabricating raw data, restored authority or a research receipt.
10. **Path and ownership:** missing-after-initialization, corrupt/oversized registry/context, unsafe names, symlinks/hardlinks, namespace/lock replacement and competing owner fail closed. Preserve relevant corrupt/original bytes.
11. **Bounds:** test subject/alias/slot/context and byte caps, including partial attempts. Repeated operations stay bounded and cannot grow unlimited history.
12. **Regression isolation:** all protected baseline source entries and existing raw/archive/label fixtures remain unchanged. No source effect on capture, Health, transport or current P1 behavior.

The store can validate supplied typed assertions and durable bindings; these tests cannot prove actual human consent, person identity, live wearer, hardware capability, Health isolation or Watch acknowledgement. Those require the later approved UI/runtime/physical workflows.

## 11. Verification, reporting and next gate

After implementation within the ratified scope, run the focused tests, full core regression and both OS 27 Release compilation checks in separate build output locations. No simulator/UI or physical action is part of this package. Preserve raw commands/results privately and record synthetic evidence, exact changed files/line counts and a new immutable source manifest.

Obtain a separate read-only working-tree review before proceeding to participant-aware setup wire 2. Formal committed-HEAD review, exact-HEAD CI and physical evidence remain distinct later gates under the repository's Git policy.

**One next action:** independently review this exact proposed contract, then obtain director ratification and the statistics author's frozen baseline before tests or production edits. Actual consent text/retention, guest acquisition, setup wire 2, Watch Start, versioned labels and verified research-bundle behavior remain separate bounded packages.
