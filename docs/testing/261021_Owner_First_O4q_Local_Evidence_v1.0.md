# Owner-first O4q lifecycle checkpoint

21 October 2026. **BLOCKED / incomplete local verification. No app adoption or physical readiness.** Astra Extra High wrote the bounded production/test change, then its worker hit the usage limit. The owner subsequently restricted Astra to foundational coding and non-Astra models to other work. Independent implementation review uses GPT-6.1 Sol High; no non-Astra foundational fix has been made.

## Exact source

- Branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; unpublished work, no upstream or new Git action.
- Ratified [amendment](261021_Owner_First_O4q_Lifecycle_Amendment_v1.0.md): `d46c098f1387442ee669fa8a629927fa5b70d420be913be1888bfa16fef74eb6`; [planning review](../reviews/261021_Owner_First_O4q_Prerequisite_Review_v1.0.md): `6ad92f41a639697cd991430e569db79dec9032ce5a8fbb2206ef352ed4ee6e64`.
- [82-input source manifest](261021_Owner_First_O4q_Source_v1.0.sha256): `05598704c9e6c41aeb92faa0e3bac9c055e04074c3c5607aa56967937d54405e`. Only the existing channel source and matching tests differ from accepted O4a: production +109/−11 (120 changed lines, cap200), tests +451. All other80 inputs remain exact.
- Private `Checkpoints/04q-o4q-source.tar`: `caa5b2cef7b5b61bdaf4e7b65caec3b9d4894d65db1e7c9a691de027dd379685`. Root and reviewer checked current/archive identities. `O4q/03-freeze.json` records scope and native preflight.

## Results and gaps

Private artifact root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/`.

`O4q/evidence.sha256` seals all8 retained regular evidence files (excluding the inventory itself and generated build cache), SHA `24b6cafe4b4bd9974d9d2ebc424356fa4d4807c9acc0cbf2861f12e83f571240`. All82 current/archive inputs and the embedded manifest were reverified after full core04.

| Check | Observation |
| --- | --- |
| Tests-first `O4q/01-tests-first-red.log` | Preserved missing lifecycle API/constructor compilation failure. |
| Focused `O4q/02-focused-channel.log` | Runner reports **47 tests / 2 suites PASS, 253.445s**. Process has exited; the failed worker did not separately preserve a shell exit-code record. |
| Full core `O4q/04-full-core.log` | **FAIL:260 tests / 20 suites,1 issue,112.837s**; process exit1,117.853s. Command/exit/duration are in adjacent JSON files. All O4q suites passed; the complete run did not. |
| Current app-host and both Release builds | NOT RUN. The source review found a blocker; predecessor O4a builds are not transferred to this changed source. |
| Physical capture / installed candidate | NOT RUN; O4b app adoption and later packages remain held. |

Xcode native accessibility was readable before root verification; no UI action or device installation occurred. Full core uses installed Xcode27.0 (27A266a) via explicit `DEVELOPER_DIR`; no SDK downgrade or system-selection change.

## Blocking review finding

The stable local End request UUID can equal a retained/replacement wire retirement UUID through existing public `request` or `resolveObsoleteIntent` paths, or when End is latched after such a retirement. The generated-command branch guards inequality, but retained commands bypass it. This violates the ratified independent-identity requirement. See the [independent implementation review](../reviews/261021_Owner_First_O4q_Review_v1.0.md).

Required next work: Astra enforces the invariant consistently at candidate mutation/latch and persisted-journal validation boundaries, with regressions for direct request, obsolete replacement, reverse order and invalid persisted state; then refresh the source freeze and affected gates. Do not weaken the contract or silently route the fix to another model. No other source blocker has been reported by the independent reviewer.

The full-suite failure is a separate unresolved gate: `RecordingLocalCopiesTests/deletionWaitsForImportThenWithholdsAckAndPreventsResurrection()` failed at line95 because `atReceipt.wait(timeout: .now() + 10)` did not succeed. Cause is **UNKNOWN**; no harmlessness, intermittency or causal attribution to O4q is claimed. Diagnose this failure before another run; do not weaken its ordering assertions or blindly retry. No current app-host or Release build was launched after these blockers were known.

A read-only historical-log lookup used a nonexistent shorter filename; the retained log is `O4a/05-frozen-phone-release.log`. No source, data or build result changed. All runtime failures remain retained; no retry or metadata restoration was used to hide a failure.
