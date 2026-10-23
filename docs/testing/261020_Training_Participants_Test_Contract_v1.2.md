# Training participants and immutable recording context — proposed contract v1.2

20 October 2026, Asia/Dubai. Author: GPT-6 Astra, Extra High reasoning.

**Status: PENDING independent recheck and project-director ratification. Participant implementation remains HELD. No tests or production implementation are authorized by this document alone.** This v1.2 addresses the alias/withdrawal authorization gap with proposed persistent, fail-closed linked-identity fences. It retains v1.1’s consent replay, publication-to-Start ordering, mandatory raw binding and metadata-only guarantees. Earlier v1.1 clearance/ratification does not authorize implementation while this new blocker is open. The scope remains three new production files, at most 1,200 production lines and the existing storage caps; there is no linked-authorization clearing flow in this package.

Preserve [v1.0](261020_Training_Participants_Test_Contract_v1.0.md) unchanged at SHA-256 `7e93a268ff15ba567d0d82b30e14e8e61cac1dcec266c1309078e0b8af416472` and [v1.1](261020_Training_Participants_Test_Contract_v1.1.md) unchanged at SHA-256 `11f3616bf218c604ee13420c8e3ac674be763c03871b3bce9439bb54fd97ad4b`. This technical correction needs no new owner decision. Setup cadence and the selected guest-mode investigation remain unchanged.

The separate existing-motion statistics package is in progress. **This proposal remains a read-only review input until independent recheck, director ratification, the statistics author’s final source freeze and the root coordinator’s explicit baseline handoff. Reconcile that final baseline before creating participant tests or production files.** Do not transfer its evidence, or the earlier P1 evidence, to a changed source state. No UI, Git publication, installation, release or third-party collection is authorized here.

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

### Linked identity cannot transfer authorization

Same-person aliases are identity-resolution metadata for later reviewed analysis. They never grant or merge consent, copy an owner attestation, authorize Health access, reassign original subjects or clear a withdrawal. The bounded linked-set calculation below exists only to block unsafe collection; it is not automatic research grouping or holdout allocation.

- When a reviewed alias or enrollment-resolution change establishes that distinct keys identify the same person, commit a persistent **linked-authorization-unresolved fence for the entire known linked set**, including existing members on either side. Conservatively fence every valid join, even when no member is currently withdrawn. Membership follows the known same-person links without regard to alias direction or canonical-target choice, within the existing subject/alias caps.
- Preserve every original key, consent-record binding, per-key decision generation, withdrawal barrier and exact subject/device owner attestation. The join and all affected fences must be part of the same atomic checksummed registry replacement; there is no committed intermediate state where the alias exists but another linked key remains eligible for collection.
- Do not reject an otherwise valid reviewed same-person join merely because one member is withdrawn while leaving the other member’s old grant usable. Record the correction and the blocking fence together. The existing structural rules still reject cycles, conflicting targets and cross-study links; a rejected request is not a successful identity resolution. Storage failure poisons the owner and preserves the §9 blocked/reconciliation rule, never returning a successful join or permission to continue from an old snapshot.
- Any later withdrawal on any already-linked key preserves the unresolved fence across **every** known linked collection path and advances the applicable registry/decision state. No canonical-key shortcut may inspect only one member’s consent. The existing fence already blocks the whole set; recording another withdrawal cannot weaken it.
- Adding another known member expands the persistent fence to the entire resulting set and advances the identity-resolution revision/digest and registry revision. Every prior authorization snapshot or proposed resolution bound to the old set becomes stale. Alias direction, slot reassignment, selection, ordinary re-consent, a new consent-record ID, enrollment replay and reopening the store cannot clear or bypass the fence.
- This package exposes the unresolved status and rejects collection publication for every fenced key, including an otherwise identical duplicate publication. It has **no public clear, reset, override or bypass operation** for linked authorization. Per-key grants may remain as historical/current decision records, but they are not effective collection authorization while this fence exists.

A future clearing flow is explicitly deferred. It would require separately approved reviewed reconciliation bound to the **current identity-resolution revision/digest, exact linked set, every relevant per-key consent/withdrawal barrier and decision generation, and expected registry revision**. An ordinary grant or re-consent acknowledgement is insufficient. Any membership change invalidates that reviewed resolution. No such flow or token is implemented here.

Normal reviewed transfer/restore of an unchanged stable study/participant key, with no new same-person link or ambiguous-key resolution, remains the ordinary enrollment path. It does not create an alias or a new linked-authorization fence, and it cannot clear a fence that already exists.

## 5. Consent, account-owner role and acquisition policy

Consent references must identify actual information, protocol and retention-policy versions/digests. Include the consent-record ID/revision/digest, subject, recorded decision/time and explicit purpose scopes. There is no default consent and no fabricated record of a participant agreeing.

Collection, research/model use, private export and optional Health/location scopes remain explicit. Health/location scopes are not implied by collection consent. A context requires granted collection scope matching its actual protocol and subject. Unknown, declined, withdrawn, conflicting or wrong-subject consent cannot authorize a new context for collection.

`recordConsent` is a monotonic state transition, not last-write-wins replacement:

- Bind each consent-record ID permanently to its exact study/participant and protocol identity. Reject subject/study/protocol reassignment under that ID. A different protocol needs its own correctly bound record and cannot reset the subject’s withdrawal state.
- For an existing ID, reject a revision below its persisted high-water revision. An equal revision is idempotent only if its canonical record and digest are identical; an equal revision with conflicting content/digest fails closed. A higher revision must satisfy the allowed decision transition, subject, protocol and scope checks. Revision overflow fails explicitly.
- Persist a withdrawal barrier and monotonically advancing consent-decision generation for the study/participant key, independent of any particular consent-record ID or protocol. Withdrawal retires the prior collection grant. Neither an old grant, a higher revision that silently changes withdrawn to granted, a new consent-record ID, enrollment restoration nor a protocol change clears that barrier.
- Re-consent requires an explicit reviewed transition: a newly documented affirmative decision, exact subject/protocol/scopes, and an acknowledgement binding the current withdrawal barrier/generation/digest and expected registry revision. Reject missing or stale acknowledgement and replay of an earlier re-consent transition. The store validates these references; it cannot prove a human actually consented. A valid per-key transition advances the decision generation and never rewrites historical contexts or erases the prior withdrawal fence. It cannot clear the separate linked-authorization-unresolved fence or authorize a different linked key.
- Keep consent high-water/ID-binding and withdrawal replay guards in the bounded registry. Never evict a replay guard to accept another record or reset it when another protocol is selected. If the existing byte/entry bounds cannot retain required guards, fail explicitly; do not add unlimited history or broaden this package’s storage limits.

Every accepted consent state change advances the committed registry revision; an exact idempotent repeat does not manufacture a new decision. Registry snapshots expose the current decision generation, per-key barrier and linked-authorization status so publication can reject stale or fenced consent. A non-linked key remains blocked after withdrawal until a valid reviewed re-consent transition has committed. Every linked key remains blocked by §4 even after valid per-key re-consent; no clearing transition exists in this package.

Actual participant information/consent text, the retention duration and withdrawal process remain unresolved and must be approved before third-party collection. A policy reference is not a substitute for that real process. TestFlight installation is not research consent. Synthetic test consent must be labelled synthetic.

The registry's device-account-owner subject binding requires explicit wearer/owner attestation bound to the **exact subject key and device/installation context**. **Never infer owner status from Player 1, installation ownership, the currently selected slot, a same-person alias or its canonical target.** An attestation for A cannot promote B to owner, even when A and B are linked; resolving enrollment cannot copy or reassign the role. Do not collect an Apple account identifier. Keep another participant's owner identity out of a guest's exported context.

Acquisition policy is frozen with the subject. Wearer/account relationship is separate from acquisition selection: the owner may also choose the same ordinary, non-workout motion path as a guest. A declared policy does not establish that the future adapter works:

- Owner-workout/owner-history policy is permitted only for an explicitly attested account-owner wearer, with the relevant actual consent.
- A guest policy prohibits app Health workout and owner-history access. It records the intended non-workout motion policy and declared capability, not a claim that the candidate acquisition path works.
- Changing participant or acquisition policy later requires retiring preparation authority and closing the prior participant's observation/recovery resources before new Start. This package supplies metadata constraints only; lifecycle/resource enforcement belongs to later integration.

A historical context records the consent/protocol applicable at collection; it is not perpetual authorization for future use. The latest registry decision must be consulted by later collection/export/withdrawal flows. This package persists local consent decisions and barriers but implements neither remote consent propagation nor capture-stop, deletion or withdrawal execution.

Local withdrawal and remote acknowledgement are separate facts. A phone-side request cannot instantly revoke an offline Watch’s unseen state. Later integration must distinguish requested/last-reported state from the Watch’s actually acknowledged applied revision and must not claim silent global revocation. Propagation, acknowledgement, disconnection policy and actual recording/resource shutdown require a separate focused protocol gate and physical verification. This document does not change the approved ability of an already-started recording to operate without phone connectivity.

## 6. Immutable recording context

`TrainingRecordingContext` schema version 1 is a companion record for `referenceTraining`, separate from raw recording schema version 1. Its creation/publication does not imply that capture happened.

Freeze these fields before samples:

- Recording ID and SHA-256 of the **exact canonical raw `metadata.json` bytes**, using the existing validated metadata encoder and SHA helper.
- Study/participant/enrollment identity and reference-collection mode.
- Collection-session ID supplied by the future **per-participant practice controller**, retained across that participant's sets. Never generate a new session ID automatically for every recording or reuse a setup revision as the session ID.
- Participant-aware setup wire version, preparation identity/revision/digest, phone origin installation epoch, and both Watch runtime/preparation generations.
- Exact consent, information, research protocol and retention-policy references/scopes, including the validated subject consent-decision generation.
- Acquisition policy, explicit owner/guest relationship attestation, declared capability/source mode and phone/Watch installation provenance.
- Actual playing arm, usual hand, Watch wrist/crown, device/OS/build and protocol details, checked against the raw metadata where represented there.

Use `PlayingArm` and existing metadata types where compatible. Canonical encoding covers all context fields. The capability declaration is a pre-start observation/declaration, not an achieved sample rate or later data-quality result. Preserve the difference.

**Exact raw binding is mandatory at construction and publication.** A validating factory requires the exact raw `metadata.json` bytes, validates their canonical encoding with the existing metadata codec, checks recording ID and every overlapping context field, and computes the SHA-256 itself. It returns an immutable `TrainingValidatedContext` with a private initializer and no public/memberwise/decoding bypass. The token binds both the canonical context and those exact raw bytes; callers cannot supply only an asserted digest. Store publication accepts this validated token only and rechecks the current registry constraints. A decoded/read-only context is not publishable until passed through the same factory with required raw bytes. There is no manually constructed unbound publication path and no optional validation call whose omission could bypass binding.

Setup provenance explicitly targets the forthcoming **participant-aware wire version 2**. P1 wire version 1 did not bind a participant. This package validates typed reference structure and consistency; a later wire/channel package must prove that the full accepted payload's canonical digest includes subject/mode/consent/acquisition policy. It cannot be fabricated from a P1 acknowledgement.

The context subject and the reference-label author are separate facts. Do not overload `.ownerSelf`. Versioned participant-self/observer labels, actual event timing/uncertainty and export compatibility are later packages. Manual intended drill remains manual intent, never a detected shot class.

Historical recordings without context stay participant-not-recorded/unassigned. Current UI selection must never supply their missing identity. Supplementary attestations, if later justified by evidence, require a separate dated mechanism and cannot rewrite originals.

## 7. Proposed API boundary

Concrete names may be refined during independent review, but responsibilities remain bounded:

- Value types: `TrainingParticipantKey`, `TrainingEnrollment`, `TrainingLocalSlot`, `TrainingIdentityAlias`, `TrainingConsentReference`, `TrainingSubjectBinding`, `TrainingAcquisitionPolicy`, `TrainingPreparationProvenance`, `TrainingRecordingContext`, opaque `TrainingValidatedContext` and `TrainingContextPublication`, all within the three allowed files.
- `TrainingParticipantStore` opens one exclusively owned namespace and exposes immutable snapshots/exact-key lookup with the exact committed registry revision, identity-resolution revision/digest and explicit linked-authorization-unresolved status. A consent record returned by lookup is not an authorization result. Registry operations are serialized by its exclusive owner.
- `enroll(_:reviewedAcknowledgement:)`, `assignSlot(_:to:)`, `selectParticipant(_:)`, `registerAlias(_:reviewedAcknowledgement:)` and monotonic `recordConsent(_:reviewedReconsent:expectedRegistryRevision:)` make explicit bounded registry changes. Re-consent acknowledgement is required precisely for the transition in §5; it cannot be fabricated by the store. Each mutation returns its committed revision/snapshot, or an explicit failure. No return claims the future recorder actor has reconciled that state.
- `TrainingRecordingContext.validated(fields:exactRawMetadataBytes:)` is the required factory for the privately initialized publication token described in §6. Exact public spelling may be refined; the non-bypassable boundary may not.
- `publishContext(_ validatedContext: TrainingValidatedContext, expectedRegistryRevision:)` rejects any linked-authorization-unresolved key and validates the exact current subject, consent decision generation, acquisition/owner policy and expected registry revision before durable publication. Return `TrainingContextPublication` containing the exact validated registry revision, immutable context/binding identity and metadata-only disposition: `newlyPublished` or `alreadyExisting`. Even the duplicate path performs these current checks; neither disposition grants Start authority.
- `readContext(recordingID:)` reports metadata-only `absent`, `valid`, `partial` or `corrupt` state. A valid result establishes context-file integrity only. Without inspecting/joining the corresponding raw store, this package cannot classify a context as an orphan, establish captured samples or verify a research bundle.

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

Apply byte and entry caps together; reaching either fails explicitly. Linked-set membership, original keys and authorization fences must remain inside these existing bounds; never evict a member or fence to make another grant fit. These local storage limits are not claims about cohort size, recording duration or supported measurement performance.

Use descriptor-relative no-follow access, validated names, a single exclusive store owner, bounded canonical checksummed registry replacement and immutable context publication. Validate file type/link count and namespace/ownership identity. Reject symlink/hardlink/path drift, conflicting content, unsupported versions/fields, non-finite values, invalid IDs/revisions/digests and oversized input.

An existing namespace with missing/corrupt registry fails closed; never silently reset enrollment, consent high-water/withdrawal barriers, linked-authorization fences or select an owner. Decode/reopen must verify that every member of a known linked set remains fenced; incomplete/conflicting fence state is corrupt, not an opportunity to reconstruct a grant. Whole-namespace deletion cannot prove whether this was a new installation or erased state: enrollment restoration must be explicit, and unresolved new identity remains provisional.

Context files are write-once per recording ID. Exact duplicate content is idempotent for storage/inspection only. Conflicting content cannot replace the original. Partial/failed context directories remain bounded evidence and the recording ID cannot be reused for capture. Do not automatically promote interrupted temporary content into a valid context.

A registry mutation cannot rewrite any immutable context. Slot, alias, consent or display changes cannot reassign existing samples. No method writes into existing raw recording directories.

## 9. Pre-start ordering, linearization and crash semantics

This package supplies pure types/store behavior. **The coordinator and lifecycle rules below belong to later Watch Start integration, not to this three-file implementation.** A store revision or publication proof alone cannot close an actor reentrancy race.

The later recorder actor/coordinator exclusively owns a live authorization generation, a reconciled committed-registry revision/snapshot, and a blocked/pending-mutation state. Every registry mutation relevant to collection authority must pass through this coordinator: consent/re-consent/withdrawal, selection, owner/guest role or acquisition policy, enrollment/identity changes, and any other mutation that advances the consulted registry revision. Neither UI nor transport may write around it. Conservatively routing all registry mutations is acceptable.

**Mutation admission rule:** while isolated to that coordinator, invalidate pending Start tokens and advance the live authorization generation **before dispatching any asynchronous registry mutation**. Mark admission blocked before the first suspension. Mutations are serialized; only their authoritative committed result may advance the actor’s reconciled revision/snapshot. A failed, cancelled or ambiguously durable mutation leaves Start blocked until explicit store reconciliation succeeds. Reconciliation never revives a pre-mutation token or previous physical/preparation authority. An asynchronous read alone does not protect against a subsequent mutation.

The later Start sequence must have one defined linearization point:

1. On the recorder actor, require a reconciled snapshot with no pending/failed mutation, no linked-authorization-unresolved fence for the subject, and valid current local preparation/physical authorization. Freeze a fresh recording ID, exact canonical raw metadata, accepted participant-aware setup, subject/consent/acquisition policy, both setup generations, **authorization generation** and **committed registry revision** in an immutable pending-Start token. Obtain the required validated context binding from those exact raw bytes.
2. On the exclusive store owner, require that expected registry revision and all exact current registry constraints. Publish and synchronize context metadata, returning its exact validated registry revision, context/binding identity and `newlyPublished`/`alreadyExisting` disposition. The proof remains metadata-only. A store operation must not reenter a conflicting registry mutation while performing validation/publication.
3. Back on the same recorder actor, match the pending token against the live authorization generation, live reconciled committed revision, publication’s validated revision, both setup generations and exact context/binding identity. Require `newlyPublished`, no pending/failed registry mutation, no cancellation, valid wearer/configuration/capability and acknowledged shutdown of the previous participant’s resources. Existing/partial attempts cannot be used for Start.
4. **Without an intervening `await` or actor suspension**, perform the final actor-owned admission transition and invoke raw-writer/start admission from the exact bound metadata. This indivisible actor turn is the local Start linearization point. If preparatory work requires a suspension, finish it before this final check and repeat the entire check on return; stale prepared resources are discarded without sample admission. The eventual implementation must keep file I/O off the main actor and must not introduce an unchecked suspended continuation that can create/admit raw capture after authority changes.

A withdrawal, selection or role/policy change handled by the coordinator before step 4 advances the generation immediately, even while its store mutation is pending or ultimately fails; the earlier Start continuation is rejected. If step 4 linearizes first, a later change must be treated as a change to an already-admitted capture and execute the separately approved stop/resource-shutdown policy. It cannot retroactively redefine ordering or relabel samples. No other local mutation path may bypass this ordering. A request still unseen on another device has not linearized here; the acknowledgement/remote-visibility limit in §5 remains explicit.

This is a **future integration guarantee**, conditional on implementing and testing that coordinator. The pure store in this package can return a validated revision/snapshot and enforce its serialized storage checks; it cannot enforce actor generations, actual wearer, physical confirmation, remote delivery or runtime shutdown.

There is **no claimed atomic transaction across context and existing raw directories**. Failure before completed metadata publication returns no success. Failure after atomic visibility but before synchronization/return may leave a whole context but still returns failure. Cancellation or raw-writer failure can leave context metadata without captured raw data. The store reports only metadata validity/partial/corrupt state; **only later integration that joins the raw and context stores may classify a context as orphaned**. Crash after raw creation is assessed under existing raw interrupted-recording semantics. Preserve failed IDs; create a fresh recording ID for a new Start.

`TrainingContextPublication` means only that context metadata was durably published or that exact existing metadata was found after validation at the reported registry revision. Its new/existing status is a storage fact. It is not permission to Start, proof of samples, a complete-recording result or a verified research receipt. Reading an identical context after relaunch cannot restore preparation/consent, replace the coordinator’s token or resume capture.

Existing `PSLReceipt1` and raw archive-v1 verification remain limited to their existing raw/timeline/label components. A later outer research bundle or deliberate archive evolution must verify every included participant/context/label/telemetry component separately. Never silently drop provenance for an older peer or call raw-only verification a verified research transfer.

## 10. Tests defined before production

All fixtures are synthetic. Create the new tests only after this contract is cleared/ratified and the statistics source is frozen. Preserve the expected initial missing-type compile failure and every later failure; no automatic retries, assertion weakening or hidden resets.

1. **Literal schemas:** independent expected canonical enrollment/context bytes and digests; round trips; versions, finite vocabularies, IDs, revisions, required references and byte limits. Reject unknown/extra/conflicting fields and noncanonical representations.
2. **Enrollment restoration:** second installation/reinstall with reviewed enrollment preserves subject/study IDs while installation epoch differs. Repeated identical import is idempotent; conflicting enrollment/subject assignments fail. Missing enrollment cannot silently create an enrolled independent player.
3. **Slots and selection:** all three slots, reuse and optional alias changes preserve existing context bytes. Slot reassignment cannot silently change selected identity. No merge by slot/name; selected subject persists through valid reopen.
4. **Explicit aliases and authorization fences:** direct same-study linkage only; reject cycles, conflicting targets and cross-study links. Test withdrawn A plus B’s older grant with B → A and separately A → B: the valid reviewed link commits, all original IDs/barriers remain, and collection through either key is blocked. Test a join with grants on both keys, then withdrawal on either key; every linked path stays blocked. Reopen, select either key, change slots, replay old/new consent IDs and perform otherwise valid per-key re-consent: none clears the fence. Adding C expands the fence to A/B/C and invalidates old identity-revision/digest/set snapshots. No public clearing/bypass API exists. Identity-resolution revision/digest changes while original contexts remain unchanged; no analytics/group allocation occurs. Normal same-key enrollment restoration without an alias remains usable when otherwise authorized.
5. **Unknown provenance:** missing context, provisional or conflicting identity remains explicitly unresolved/unassigned; lookup never substitutes current selection or owner.
6. **Consent and replay:** absent, withdrawn, wrong-subject, wrong-protocol, stale-record revision and stale consent-decision generation reject publication. Verify grant → withdrawal → replay old grant; withdrawal → new-record-ID grant; protocol change after withdrawal; higher-revision grant without reviewed re-consent; same-ID/same-revision conflicting digest; subject/protocol reassignment; stale or replayed re-consent acknowledgement. Reopen preserves all fences. An exact duplicate is idempotent; explicit valid reviewed re-consent advances the generation and permits correctly bound subsequent publication only for an otherwise eligible non-linked key. Linked keys stay fenced. Bounds never evict replay guards or linked members/fences.
7. **Owner constraints:** owner role is not inferred from Player 1, alias direction or canonical identity. Link an exactly attested owner A with B and verify that B gains no owner role, workout permission or owner-history access; attestation remains bound to A and its exact device context. Guest-workout/owner-history policy is rejected. Owner and guest can both declare ordinary non-workout acquisition, without reporting the unverified adapter as operational.
8. **Mandatory frozen binding:** the public construction/publication API requires exact raw bytes and the privately initialized validation token; a digest-only or decoded context cannot be published. Reject noncanonical/invalid raw bytes, recording ID, exact metadata, subject, setup version/generations, registry revision, arm/orientation and acquisition-policy inconsistencies. All copied raw metadata remains byte-identical.
9. **Publication proof and immutability:** exact duplicate context is storage-idempotent and reports `alreadyExisting`; a first successful publication reports `newlyPublished`. Both carry the exact registry revision validated by the store and match the immutable binding identity. Changed/stale expected revisions, consent or linked-authorization status fail, including duplicate publication after withdrawal or a same-person join. Conflicting write cannot alter the original. Neither result grants capture authority or ID reuse.
10. **Crash boundaries and metadata vocabulary:** inject failures around directory creation, temporary write, file synchronization, publication and directory synchronization. Reopen distinguishes metadata-only absent/valid/partial/corrupt state. Inject failures around an alias/fence registry replacement and verify that every surviving committed join has its full linked fence; partial or contradictory registry state fails closed. Without a raw join, no result uses orphan/captured/complete terminology or fabricates raw data, restored authority or a research receipt.
11. **Path and ownership:** missing-after-initialization, corrupt/oversized registry/context, unsafe names, symlinks/hardlinks, namespace/lock replacement and competing owner fail closed. Preserve relevant corrupt/original bytes.
12. **Bounds:** test subject/alias/slot/context and byte caps, including partial attempts. Repeated operations stay bounded and cannot grow unlimited history.
13. **Regression isolation:** all protected baseline source entries and existing raw/archive/label fixtures remain unchanged. No source effect on capture, Health, transport or current P1 behavior.

The store can validate supplied typed assertions and durable bindings; these tests cannot prove actual human consent, person identity, live wearer, hardware capability, Health isolation or Watch acknowledgement. Those require the later approved UI/runtime/physical workflows.

**Required later integration tests, outside this package:** deterministically suspend Start after context publication; admit withdrawal, same-person alias/enrollment-resolution change, selection change, owner/guest role change or acquisition-policy change through the coordinator; then resume the old continuation and prove raw creation/sample admission is rejected. Cover mutation still pending, mutation failure/ambiguous completion, a stale same-revision snapshot, asynchronous reconciliation and reversed completion attempts. Prove generation invalidation happens before dispatch, exact publication/live committed revisions and both setup generations are checked, no suspended gap exists between final validation and raw admission, and an `alreadyExisting` result cannot Start. Separately test the opposite linearization order (Start first, then change) against the approved shutdown policy. Phone-requested but unacknowledged/offline Watch withdrawal must display requested/last-reported status without claiming actual remote application. These tests and the remote acknowledgement protocol require their own focused integration gate; passing pure-store tests is not evidence they ran.

## 11. Verification, reporting and next gate

After implementation within the ratified scope, run the focused tests, full core regression and both OS 27 Release compilation checks in separate build output locations. No simulator/UI or physical action is part of this package. Preserve raw commands/results privately and record synthetic evidence, exact changed files/line counts and a new immutable source manifest.

Obtain a separate read-only working-tree review before proceeding to participant-aware setup wire 2. Formal committed-HEAD review, exact-HEAD CI and physical evidence remain distinct later gates under the repository's Git policy.

**One next action:** independently recheck this exact v1.2 proposal, then obtain director ratification and the root coordinator's explicit handoff of the statistics author's final frozen baseline before tests or production edits. Linked-authorization reconciliation/clearing remains deferred; this package only persists and enforces the unresolved fence. Actual consent text/retention, guest acquisition, setup wire 2, Watch Start, versioned labels and verified research-bundle behavior remain separate bounded packages.
