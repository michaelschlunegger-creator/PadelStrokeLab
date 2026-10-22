# Training participants — technical package-split amendment v1.3

20 October 2026, Asia/Dubai. Author: GPT-6 Astra, Extra High reasoning.

**Status: PENDING independent recheck and exact-amendment director ratification.** The director agreed to split the work to preserve readability and every v1.2 safeguard. That agreement authorizes this documentation amendment only. No participant tests, production files or builds may start before the coordinator's explicit handoff of the final reconciled statistics baseline. Final statistics UI/evidence work remains in progress at authoring.

## 1. Authority and effect

This amendment incorporates the unchanged [participant contract v1.2](261020_Training_Participants_Test_Contract_v1.2.md), SHA-256 `7e6c11587182395a654d0294a1932082242534f2490bfa74275930bc4b4572a1`. Its substantive identity, consent, linked-authorization, owner/guest, mandatory binding, persistence, crash and future integration requirements remain binding.

Only v1.2's single-package file/line budget and the allocation/sequencing of its tests and evidence are replaced by the two packages below. No behavioral safeguard is removed or deferred merely to fit a line budget. The separate runtime/transport/reconciliation work already deferred by v1.2 stays deferred.

Preserve v1.0, v1.1 and v1.2 unchanged. Their historical status paragraphs remain historical; current clearance/ratification and implementation release belong in `GATE_CARD.md` and package evidence. This amendment does not itself clear its independent review or release the baseline hold.

Planning checkout: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, with intentional unpublished changes and no upstream. The current statistics candidate is the private 69-entry source19 manifest, SHA-256 `cd0f9af6fd4d7bb3ea0873983c1f5d34441589edd9a8cc297cbf5ccb83b7ee9a`; its final full UI/evidence reconciliation is not yet the participant startup handoff. P1's older 64-entry manifest, SHA-256 `ca4332e66eaf46077a99df949d1d9d0d20895917c02af21db0fce24b64b15171`, is historical and must not substitute for that final integrated baseline.

Before each implementation package, read the repository authority/governance and active gate, reconcile exact branch/HEAD/remote/PR/worktree ownership, validate the coordinator-released source manifest and verify Xcode 27 with both OS 27 SDKs. Every Swift/Xcode invocation uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. A new source state needs new applicable evidence; preserve failures and earlier manifests.

## 2. Two bounded packages

All production paths below are under `Packages/PadelCore/Sources/PadelCore/`; all corresponding test paths are under `Packages/PadelCore/Tests/PadelCoreTests/`.

| Package | Allowed new production files | Hard production cap | Allowed new tests |
| --- | --- | --- | --- |
| A — pure participant policy | `TrainingParticipant.swift`; `TrainingParticipantRegistry.swift` | Two files; 1,000 total production lines | `TrainingParticipantTests.swift`; `TrainingParticipantRegistryTests.swift` |
| B — context binding and persistence | `TrainingRecordingContext.swift`; `TrainingParticipantStore.swift` | Two files; 1,000 total production lines | `TrainingRecordingContextTests.swift`; `TrainingParticipantStoreTests.swift` |

Four production files result in total. Each package has its own cap; unused capacity does not transfer between packages. Count complete readable source, including declarations, validation and comments. No minification, compressed control flow or relocation into test/support files to evade the cap. If a package cannot fit cleanly, stop before exceeding its scope and obtain a separately reviewed amendment.

Package A covers the participant identity/authorization policy domain. Package B covers immutable context provenance and bounded persistence, at most two Level 3 domains. Both are pure core metadata work, with no connection to the live apps.

**Package B must not modify either Package A production file or its frozen tests.** Establish the required validated value/transition/codec interfaces before A's freeze. If B discovers a missing or incorrect A interface, scope and independently review that A change separately, rerun affected A evidence and freeze a new baseline before continuing B. Do not hide it in B's allowance.

Existing source/test helpers may be read and reused without editing them. No `RecordingPaths.swift`, package manifest, project file or shared helper edit is included. Each package may add its own focused documentation, raw evidence outside the repository and a new immutable source manifest; these are not production code.

## 3. Package A: validated values and pure state transitions

`TrainingParticipant.swift` defines the bounded immutable participant, enrollment, reviewed-acknowledgement, consent/policy-reference, exact subject/device owner-attestation and acquisition-policy values needed by v1.2. Wearer/account relationship and acquisition selection are separate facts. Both owner and guest may declare ordinary non-workout motion; only an exactly attested owner-wearer with relevant consent can declare owner workout/history policy. A declaration does not prove actual capability, permission or resource isolation.

`TrainingParticipantRegistry.swift` owns immutable validated registry state, canonical checksummed serialization and pure transitions for enrollment, slots/selection, consent and explicit same-person links. It performs no filesystem access, transport or asynchronous work. Names may be refined within review; the following boundaries may not:

- State is not a publicly mutable collection of records. Public properties and nested values are immutable; no setters, arbitrary-state replacement initializer, unchecked memberwise initializer, decoding shortcut or fence-clearing method may bypass the invariant checks.
- Controlled bootstrap produces only a fresh empty validated value for an explicit local installation epoch. It cannot manufacture enrolled subjects, consent, owner roles or accepted practice. Its existence does not authorize replacing an existing persisted registry; Package B alone decides whether a genuinely new namespace may initialize.
- A transition takes the current validated state, explicit command/review references and expected registry revision. It returns a completely validated next value or an error. Failed transitions leave the original value unchanged. Exact idempotent repeats preserve the applicable revision; mutations advance the proper registry, identity-resolution and consent generations without overflow.
- Treat an alias join and its entire linked-authorization fence as one pure next-state transition. Retain all original IDs and per-key withdrawal guards. Every known member stays fenced, regardless of alias direction, subsequent grants or ordinary re-consent. There is no public clearing/bypass operation. A consent record or canonical alias target cannot substitute for effective collection authorization.
- Effective collection-policy checks are explicit, state-scoped and require the exact selected subject/enrollment/consent, local decision generation, owner/device relationship and acquisition policy. They reject missing/conflicting required policy bindings, stale revisions and every linked-authorization fence. Preserve v1.2's provisional/unresolved provenance rules: eligibility or serialization must never promote a provisional identity into enrolled independent-player evidence. An eligible result is metadata policy evaluated against that value; it is neither durable state, a live recorder acknowledgement nor Start permission.
- The public registry decoding boundary accepts bounded canonical versioned bytes with a checksum, validates the checksum and full nested/cross-record invariants, and only then constructs the immutable state. It must reject unknown/duplicate fields, noncanonical representations, inconsistent references/revisions, incomplete linked fences and unsupported versions. Correctly recomputed checksums cannot legitimize semantically invalid state. Do not expose an alternate public `Decodable` or constructed-snapshot path that skips these checks.
- Encoding is canonical, validates the complete state and enforces the existing 64 KiB registry-envelope cap. Subject, alias and slot caps remain 64, 64 and 3. Consent ID bindings, replay guards and linked members/fences are retained within those bounds; capacity failure never evicts safeguards. Checksums detect byte corruption, not human identity, consent or malicious rewriting.

The A-to-B interface must let B decode validated registry bytes, apply a checked transition, encode its complete candidate state and re-evaluate collection policy against B's current owned state. It must not require B to mutate internals or fabricate a snapshot/token. B will not accept a caller-supplied eligible result as a substitute for its own live revision and policy checks.

### A tests defined before production

Use only synthetic records and existing reusable fixtures without editing protected files.

1. Independent literal canonical enrollment/registry bytes and digests; encode/decode round trips; schema/version/field/enum/date/revision/digest validation. Recompute checksums around deliberately invalid nested state and prove semantic validation still rejects it. Exercise the real public construction/decoding boundaries.
2. Stable same-key enrollment transfer/restore and exact duplicates; new installation epoch; conflicting identity assignments, provisional/unresolved identity and name/slot non-inference. Normal same-key restoration without a new alias does not create or clear a linked fence.
3. Independent selected subject and three slots; reassignment/alias-display changes cannot silently change selection or historical identity references. Expected-revision mismatch and failed transitions leave the original value unchanged.
4. All v1.2 consent replay cases: older revisions; equal revision/conflicting digest; wrong subject/protocol; withdrawal followed by old grant, new record ID, changed protocol or unreviewed higher-revision grant; stale/replayed re-consent acknowledgement. Valid reviewed per-key re-consent affects only the correctly bound otherwise-eligible key and never clears a linked fence.
5. A withdrawn plus B's older grant, with B → A and separately A → B: the valid reviewed join produces a complete fenced set and neither key is collection-eligible. Test withdrawal after a join, added-member expansion/stale resolution, grant/re-consent replay and serialization round trips. Preserve every original ID/barrier; no fence-clearing API. Reject structural cycles, conflicting targets and cross-study links without inventing a successful resolution.
6. Exact owner attestation cannot transfer through enrollment resolution, slots or aliases. A's attestation on device X grants B no owner privileges and grants A none on unrelated device Y. Guest workout/history policy fails; owner and guest ordinary-motion declarations remain representable without claiming an operational adapter.
7. Distinguish a recorded grant from effective collection eligibility. A linked subject, or state with a missing/conflicting required policy binding, still fails the policy check despite a recorded grant. Validate required references, selected identity, consent generation and policy consistently, including after canonical encode/decode; provisional status must never become enrolled independent-player evidence.
8. Boundary/overflow cases for subjects, aliases, slots, revisions and total encoded registry bytes; repeated operations retain replay guards and fences until a stated limit fails explicitly. No unbounded history, silent reset or state mutation after failure.

Serialization round trips test reconstructing validated values only. They are **not** disk reopen, durability, locking, crash recovery or capture evidence. Those checks belong to B or later integration.

## 4. Package B: mandatory binding and exclusive persistence

B begins only after A's exact-source tests/builds, independent read-only package review, source freeze and coordinator acceptance/handoff. B consumes A's frozen interfaces unchanged.

`TrainingRecordingContext.swift` supplies v1.2's immutable schema-v1 companion context, participant-aware wire-v2 provenance, exact per-participant collection-session reference and required raw-metadata binding factory. The privately initialized validated token requires the exact canonical raw metadata bytes and computes their digest after existing metadata validation. A decoded or manually constructed unbound context is not publishable. Raw recording schema v1 and existing metadata bytes remain unchanged.

`TrainingParticipantStore.swift` is the synchronous exclusive owner of the dedicated `TrainingReference-v1` namespace. It uses A's codec/transitions, performs no-follow bounded I/O and atomically persists complete registry candidates before returning committed revision/snapshot results. A caller cannot install a bootstrap/arbitrary registry over existing storage. Missing/corrupt initialized state fails closed.

Preserve all v1.2 publication, ownership and crash rules: exact current revision/consent and linked-fence checks even for duplicates; immutable context publication; metadata-only valid/partial/corrupt/new/existing results; no orphan classification without a raw join; synchronization before success; poisoned-owner handling; no failed recording-ID reuse or automatic promotion of temporary context content. Context directories, including partial attempts, remain capped at 512; each encoded context stays within 8 KiB. No publication proof authorizes Start.

### B tests remaining from v1.2

- Required raw-byte binding and all overlapping metadata/provenance mismatches, canonical context bytes/digests, private-token boundary, exact publication revision/disposition and immutable duplicate/conflict behavior.
- Real persistence and reopen of enrollment/selection, consent high-water records and complete linked fences; A's effective-policy rejection still holds after disk round trips. Normal same-key restoration remains distinct from alias resolution.
- Atomic registry join/fence replacement and context publication with injected failures around directory creation, temporary writing, file synchronization, atomic publication and directory synchronization. Preserve failed evidence; no partial committed join can leave another linked key eligible.
- No-follow path, symlink/hardlink, lock/namespace replacement, competing owner, missing/oversized/corrupt state and unexpected entry tests on real storage paths. Verify original corrupt bytes and all protected raw/archive/label fixtures remain intact.
- Registry/context byte and entry limits, including partial attempt directories; no guard/fence eviction or reused failed IDs. No current selection inferred for historical context-free recordings.
- Full A-plus-B regression integration through the actual store, including post-join/withdrawal duplicate rejection, stale expected revisions and no owner promotion. B must not validate policy with a substitute mutable snapshot or caller-constructed authorization result.

## 5. Prohibitions and later integration

Neither package may edit existing production/tests, P1 messages/store, motion-statistics sources, capture engines/adapters, app models/views, raw recording schemas/storage, archive/import/export/receipts/deletion, labels, permissions, entitlements, signing, dependencies, project/workflow configuration or cloud/accounts. No runtime Start coordinator, Health query/workout, sensor acquisition, WatchConnectivity handler, background work, UI/test seam, installation, third-party enrollment/collection or TestFlight distribution is included.

No Git mutation, commit, push, PR, merge, branch deletion or release is authorized. Do not run simulator/UI jobs or interfere with the statistics author's reserved pair. After explicit release, only the package's authorized core tests and headless Release compilation checks are included.

The owner's app profile and Health context remain usable only when he is the wearer; aliases never grant that role. Ordinary-motion metadata for either wearer does not establish guest capture support. Actual participant information, retention duration and third-party collection approval remain unresolved.

The v1.2 future coordinator requirements remain separate gates: invalidate pending Start before asynchronous authority changes; match committed revision, authorization generation and both setup generations; no suspension between final check and admission; acknowledge old resource shutdown; distinguish requested phone withdrawal from applied Watch state. Paired adoption, wire v2, deterministic publication → change → resume race tests, actual hardware/Health isolation, labels and research-bundle verification remain unimplemented. A or B passing cannot be reported as proof of those flows. Linked-authorization reconciliation/clearing is still deferred with no bypass API.

## 6. Evidence, review and handoff

For **each** package, after its explicit release:

1. Reconcile the coordinator-released baseline and define the new tests before production. Preserve the expected missing-type initial failure and every later failure; no automatic retries or weakened assertions.
2. Implement only the named files. Record exact changed-file inventory and actual production line count. Verify every protected baseline entry remains unchanged.
3. Run the focused tests, complete core regression and both iPhone/watchOS OS 27 Release compilation checks with the explicit Xcode 27 environment and separate generated output directories. Record exact commands, source identities, results and limits; success is not a physical or live-runtime claim.
4. Freeze a new immutable source manifest and obtain a separate independent read-only review of that exact package state: review only, no modifications. Resolve blockers within a newly identified source state and rerun affected checks before acceptance.
5. Record coordinator acceptance and the next package's explicit baseline handoff. B cannot proceed from an unreviewed or changing A state. Any separately scoped later A fix invalidates affected evidence and requires a new freeze before B continues.

Local package review does not replace formal committed-HEAD review, exact-HEAD hosted CI, relevant physical evidence or user-approved Git/release gates. Reports must distinguish A's pure-value verification, B's real storage verification and the still-unperformed live integration.

**One next action:** independently recheck this exact amendment and record director ratification; then wait for the coordinator's explicit final-statistics baseline handoff before creating A tests or source. Preserve the reviewed v1.2 artifact and all earlier versions unchanged.
