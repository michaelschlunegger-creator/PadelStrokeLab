# Owner first build O2 — independent local source review v1.0

21 October 2026. Independent Codex review, Astra Extra High role. Review only: no production, test or configuration edits, builds/tests, device operations or Git mutations. This review report is the sole reviewer-authored file.

**Local package verdict: CLEARED FOR THE NEXT BOUNDED PACKAGE. No unresolved O2 blockers.** The director may release O3 from this exact source. This intentional working-tree review is not formal committed-HEAD G6, a merge verdict, physical readiness or completion of the owner-first build.

## Exact reviewed source

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Existing unpublished work remains intentional. Reviewed the complete new store and tests, reused filesystem boundaries, the approved package contract and the [O2 evidence record](../testing/261021_Owner_First_O2_Local_Evidence_v1.0.md).

- [Final source manifest](../testing/261021_Owner_First_O2_Source_v1.0.sha256): SHA-256 `29440c97a96b96eb70faf99c072f508a5b62f433f2f102f05ce0ab675e2265f9`. All **75 entries** independently match current bytes; all **73 accepted O1 entries remain unchanged**.
- Exactly two additions: `Packages/PadelCore/Sources/PadelCore/OwnerPracticeStore.swift` (**661 production lines**, SHA-256 `5cbff31f9da1d2a6e1ab7c990ec1088273518f02e827174aef59116b073afb57`) and its matching `OwnerPracticeStoreTests.swift` (**463 test lines**, SHA-256 `f6197e630ea0ff717a864719573eb013edfa0705efab4958e23d2032dd23083f`). Within the one-production-file/1,200-line limit and persistence/provenance domains.
- Evidence record SHA-256: `1a608b0bb8206a08b0e4b5c54045e8268d50d3fe2f8c805848a94e198120ac4d`.
- Private evidence directory: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O2/`. Its `evidence.sha256` is `19bd0c36b9a7f81604a5da4452c06c4f6bb9749fbc1849e24c814ac85a65f8d0`; all **nine listed entries** independently match. `06-source.sha256` is byte-identical to the public manifest.
- Private `Checkpoints/02-o2-source.tar` SHA-256 independently matches `61cd5ed2ebd2e57e58668e4ee76199cd788a5f2cc22534711432c2d05e00d5dc`. Review conclusions derive from the actual source and logs, not merely the checkpoint digest.

## Verified evidence

| Final evidence inspected | Result |
| --- | --- |
| `07-frozen-core.log` | **179 tests in 16 suites passed**, including 22 O2 tests and their parameterized cases. |
| `08-frozen-phone-release.log` | `PadelStrokeLab` Release build succeeded, generic iOS Simulator. |
| `09-frozen-watch-release.log` | `PadelStrokeLab Watch App` Release build succeeded, generic watchOS Simulator. |

Both Release logs compile the new store with OS27 `arm64`/`x86_64` simulator targets. They contain the existing App Intents metadata-extraction warning for targets without that dependency. These are compilation checks, not simulator execution, physical-device evidence or `arm64_32` validation. The reviewer inspected retained results and ran no builds/tests.

The initial missing-type failure (`01`), seven genuine missing-membership issues (`03`), and missing-`try` compile failure (`04`) remain preserved. The initial 11-test pass (`02`) and corrected 20-test pass (`05`) are intermediate evidence; the 179-test frozen run is the final source result. No intermediate pass is substituted for it.

## Findings resolved before this freeze

| Initial finding | Verified correction |
| --- | --- |
| Removing a committed guard or reserved context directory could turn protected membership into absence after reopening. | State now binds bounded count/SHA-256 membership for contexts and guards. Missing completed members fail closed live and on reopening. A single durable reservation permits only conservative empty/zero-byte stub recovery. Dedicated missing-member regressions now pass. |
| Guard lookup treated every filesystem error as absence. | Only `ENOENT` means absent. Other errors throw; guard type, link count and zero-byte size are checked. |
| An absent known namespace could be silently recreated as first use. | Explicit `createNew` and `openExisting` intents prevent reuse or missing-namespace recreation. Integration must retain initialization intent outside the namespace. Tests cover known-namespace disappearance and wrong epoch/device after lock release. |
| A throwing initializer check occurred after descriptor ownership transferred to `self`, risking duplicate cleanup. | All throwing validation and synchronization complete before ownership transfer. Failed initialization uses one local cleanup path; initialized instances use `deinit`. |

## Source conclusions and retained obligations

The synchronous, non-Sendable store uses exclusive locking, descriptor-relative no-follow access, bounded regular single-link files, exact state bytes and filesystem identity revalidation. It operates in a separate owner namespace and does not mutate raw recording directories. State is bounded at 16 KiB, contexts at 512 and minimal guards at 1,024. Full-capacity tests include a failed final slot; capacity refuses new publication without eviction. The maximum O1 consent history persists within the state bound.

Reservation state is committed before a stub, and finalized membership precedes context payload publication. Reopening may conservatively recover only the exact pending identity with unchanged committed authority. It rejects unexpected pending payloads/links, never promotes uncommitted consent or context payloads, and preserves malformed temporary state while refusing to open. Ambiguous writes poison the live store. A guard can conservatively survive a failed operation before authority advancement.

Context publication retains exact canonical metadata and immutable O1 context, distinguishes fresh/duplicate receipts and rechecks current authority/replay guards. Partial or corrupt IDs cannot become fresh captures. These receipts establish metadata publication only; O5 must still enforce a genuinely new raw ID, current generations and fresh physical confirmation, with no suspension during final admission. O2 does not establish actual wearer identity, running resources or sample completeness.

Later integration must confine the store to one serial owner and retain first-use evidence outside this namespace. Whole-container erasure cannot be inferred from a missing namespace. O9 must remove all context/metadata/pending payloads while retaining empty reserved-ID stubs and minimal replay guards; removing the reserved directory itself fails membership validation. Complete raw/HR/label/derivative/export deletion, leases and paired acknowledgements remain O9 work. Backup exclusion remains the explicitly deferred O6/O7 obligation before app storage adoption.

Keep this O2 source, O1 and all predecessor inputs frozen during dependent work. Any correction requires an identified amendment, affected verification and renewed review. Formal committed-source review, exact hosted CI, physical G7 and user-authorized publication/merge remain open.

**Next action:** director accepts this exact O2 freeze and releases the independently bounded O3 setup-channel package.
