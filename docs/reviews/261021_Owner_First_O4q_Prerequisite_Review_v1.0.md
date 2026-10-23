# Owner-first O4q prerequisite review v1.0

21 October 2026. Independent Codex review using GPT-6 Astra / Extra High for persistence, authority ordering and recovery risk. Review only: no production, test or configuration edits; no builds, tests, Git mutations or device actions. This report is the sole authorized review-file write.

## Verdict and exact proposal

**SUFFICIENT FOR DIRECTOR RATIFICATION — O4q prerequisite only.** No remaining planning blocker was found in the frozen amendment. This is design clearance, not implementation acceptance, merge approval, device readiness or permission to start O4b. The director releases implementation separately.

Reviewed [O4q lifecycle amendment](../testing/261021_Owner_First_O4q_Lifecycle_Amendment_v1.0.md), SHA-256 `d46c098f1387442ee669fa8a629927fa5b70d420be913be1888bfa16fef74eb6`.

Verified repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. The extensive unpublished dirty worktree is intentional; HEAD alone does not describe the accepted source. All **82** inputs in the accepted O4a manifest remain byte-exact. Manifest SHA-256: `e1740faaa6a217d2f650d30635735db2db92f7792b6c316e6a495a5aea4f94fe`.

## Focused findings and resolutions

| Review concern | Required resolution now present in the amendment |
| --- | --- |
| Missing durable practice identity and End request | One bounded phone-local lifecycle record inside the existing journal holds distinct practice/preparation IDs, exact owner/phone/Watch scope and optional stable local End ID. Persist it before P1 draft save and preparation dispatch. It restores bookkeeping and denial only. |
| Enrollment is the sole authority basis while authority is nil | Validate against the exact retained affirmative enrollment. Reject cancellation that would discard that basis; do not claim cancellation succeeded, infer a grant or convert End to withdrawal. Cover nil/obsolete replacement and scope failures. |
| Confusion between local End identity and wire idempotency | Preserve the local End ID. Return the same retained nonobsolete retirement command on retry. An obsolete retirement requires explicit existing resolution and a fresh wire mutation ID; no automatic rebase, replacement or second dispatched intent. |
| Premature lifecycle clearing and checkpoint early return | Require exact-scope retirement in the retained verified chain and a live O2 replay-guard check after reconciliation. When an unrelated obsolete intent prevents ordinary checkpointing, persist lifecycle clearance while retaining that intent and unpruned chain. A guard alone or unrelated transition cannot clear it. |
| Scope and creation ordering | New lifecycle creation requires collection consent, an unretired practice ID, ordinary capacity and no non-enrollment pending intent. Matching existing mapping may remain idempotent without reopening an End-pending practice. A different unresolved lifecycle cannot replace it. |
| Canonical compatibility | Omit nil, preserve old settled v2 bytes and reject expanded records through a faithful old schema using the actual canonical decoder. Reject explicit null, unknown/noncanonical/malformed fields, oversized records and foreign role/scope. Existing accepted recovery may still synchronize or compact. |
| End persistence at the byte boundary | Bound the record to512 canonical bytes and reserve64 envelope bytes until End is latched. Verify the actual encoded delta, durable latch/reopen and healthy ordinary-growth refusal using the same encoder, commit and validation paths. Later retirement capacity failure must leave End pending without a false remote-success claim. |

The existing source supports these corrections: `request` retains one authority intent; retirement carries no privacy restriction; `cancelPending` can currently discard an unsent enrollment; `checkpointPhone` has an early-return path; and `OwnerCanonical` rejects bytes that do not survive exact canonical re-encoding. These are implementation constraints, not newly verified behavior.

## Bounded implementation release recommendation

Approve only the existing `PracticeSetupChannel.swift` production file and its existing matching Core test file, within **200 changed production lines**. The explicit allocation remains O4p10 + O4a250 + O4q200 + O4b1,240 =1,700. Require a precise amendment before exceeding the cap; do not compress code or introduce hidden helper files to fit it. No app adoption, extra journal/lock/witness, P1 field, wire message, Watch behavior change or unrelated source/configuration edits are included.

The constructor-only internal lower `maximumJournalBytes` seam is sufficient and narrowly justified for real boundary tests. The director supported it in the review exchange: preserve the public production initializer and1MiB default; keep the limit immutable; accept only positive values at or below the production cap; validate before filesystem creation; reopen tests with the same limit; use the actual admission, encoding, persistence and validation paths. No mutable override, synthetic padding, alternative codec or validation bypass is permitted. The boundary evidence must include exact one-byte-insufficient and invalid-limit cases, plus normal-growth refusal followed by a successful durable reserved End latch. Compact transition sizes alone do not prove the reserve branch.

## Evidence required before acceptance

The amendment's tests-first, preserved expected missing-API red and focused regression requirements are sufficient. Implementation review must inspect the actual tests and results for:

- Pending/dispatched enrollment and HR collisions; retained enrollment basis; stable local End through explicit obsolete wire replacement; privacy fences and ordinary cancellation unchanged.
- Real durability failures and reopen ordering around lifecycle creation, P1/dispatch, End, prior-intent reconciliation, retirement/O2 application and clearance. Guard alone cannot clear; old retirement replay cannot clear a new practice. O4b must additionally prove its actual caller ordering and immediate presentation fence.
- Exact-scope clearing on the checkpoint early-return path, preserving unrelated unresolved intent and history; canonical old/new compatibility; actual byte reserve; byte/revision/I/O failure without false saved/applied claims.

Require a fresh full Core regression, affected isolated phone app-host/bootstrap regression and both OS27 Release builds, followed by exact source/checkpoint/evidence hashes, independent implementation review and director acceptance. The prior Core245/19 result cannot carry across this change. Use the installed specified Xcode27.0 toolchain, reserved simulator pair, established synthetic isolation and exact ratified default-container-test exclusion. Preserve the original O4a guard failure and the documented guard limits.

O4b remains held until O4q is accepted and separately released. Its preparation/consent/presentation generations, explicit saved-choice review, current-versus-next state, one connectivity instance, private serial bootstrap ownership and no remote Start remain required.
