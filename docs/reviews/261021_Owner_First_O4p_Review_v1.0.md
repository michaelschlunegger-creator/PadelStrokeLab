# Owner first build O4p — independent checked-read review v1.0

21 October 2026. Independent Codex review, assigned Astra Extra High role, for live persistence validation and exclusive ownership. Review only: no production/test/configuration edits, builds/tests, Git mutations or device actions. This authorized report is the only file written during the O4p review. The reviewer inspected source, tests, preserved red and final execution evidence; the reviewer did not execute the tests or builds.

**Local package verdict: CLEARED FOR THE NEXT BOUNDED PACKAGE. No unresolved O4p blockers.** The director may accept this exact freeze and separately release O4a. This is a working-tree package review, not formal committed-HEAD G6, a merge verdict, physical readiness or completion of the owner-first build. O4a and O4b remain held until their separate director releases.

## Exact source and evidence

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; intentional unpublished work with no upstream. Branch, HEAD and upstream state were independently checked. The first-build contract remains SHA-256 `f7666a8d73d5e11fa786571f294b9837d96d3768b30d9318b578ab8d762f706f`. The ratified O4 sequencing amendment is `e58ca5466a7d95dc367415106f0f8a0310eac71643afd75d699456c407314867`, with independent sequencing review `8fe7a08c934d2842662417bbd9ea1a7c71aa6aba93ad440b376f1974f142e852`.

- [O4p source manifest](../testing/261021_Owner_First_O4p_Source_v1.0.sha256): **80 entries**, SHA-256 **`d2906f11be7e1c602bde308b80938c9b4e9fd6d28c2a963fd980a5c042c4aaf8`**. All current files match. The two authorized P1 source/test entries are the only changes from accepted O3c; the other **78 inputs remain byte-identical**. No additional candidate Swift/configuration inputs were found outside the inventory.
- `Packages/PadelCore/Sources/PadelCore/PracticeSetupStore.swift`: **6 added / 0 removed = 6 changed production lines**, within the 10-line cap; 243 total lines; SHA-256 `315e96b8c1653d6a9db6996b96aa149e8d5dc398986fc2110b8c221ae3ecc141`.
- `Packages/PadelCore/Tests/PadelCoreTests/PracticeSetupStoreTests.swift`: **104 added / 0 removed lines**; 303 total lines; three added test functions, one with six parameterized cases; SHA-256 `d22fa724ac5664b55c03cb0b4a237d7f8cd688f2e48b2f25b1d1816303fe41c0`. All prior tests are unchanged.
- Source checkpoint `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/Checkpoints/04p-o4p-source.tar`: SHA-256 **`009f894249a51ff7dc3e35e28399b122d0e9b90c9ade36abbb4e57e3ab87f1ad`**. Independently verified all 80 archived payloads and the exact embedded manifest, with no other file payloads.
- [Local evidence](../testing/261021_Owner_First_O4p_Local_Evidence_v1.0.md): SHA-256 **`199f9b126cfd66826e052f5ef7e20da555477a4c533881fe65042d30ee653fa3`**.
- Private evidence directory `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O4p/`; `evidence.sha256`: **10 entries**, SHA-256 **`30a59b37c64fab7902799b829f1e4166ed5ff0ef0aa38c78a9726a223d973c81`**. Every listed payload independently matches. The private source manifest is identical to the repository manifest.

The accepted O3c manifest remains `94c51aca7a4f72669935eb7a17394f54900f6704fbe908ddc21ed9c7c6a4fc15`; accepted checkpoint `03c-o3c-source-v1.1.tar` remains `8d5099334adeddb9b57d943bf28025c6a7a33c143dff3d6f94c29b241081fb79`. Its archived payloads and embedded manifest were independently checked before comparing the bounded O4p delta.

## Behavior review

The only production addition is `public func checkedSnapshot() throws -> PracticeSetupPersistentState`, its comment and surrounding whitespace. It calls the existing private `checkLive()` and returns `snapshot` only after that call succeeds. It adds no parser, codec, write, recovery, consent, grant, acceptance or initialization behavior. The existing synchronous, exclusive, intentionally non-Sendable ownership contract and cached `snapshot` compatibility remain intact.

The frozen live check validates the held/named namespace directory, held/named regular single-link lock, bounded allowed entries and exact bounded state bytes. Any validation failure poisons the existing owner before rethrowing. The new method neither catches that failure nor returns the cached value after it. Its invoked validation path performs reads and metadata checks; no persistence mutation was added. A checked snapshot still contains suggestions/bookkeeping only and cannot restore practice authority.

The tests exercise the production store and real synthetic filesystem fixtures:

1. Five repeated fresh reads return the empty current state while preserving the complete namespace child list, regular-file bytes, device/inode identities and nanosecond modification timestamps for state, lock and directory. The same fingerprint check is repeated after real saves. Access time is correctly excluded from the immutability assertion.
2. Real preference, suggestion and explicit-bookkeeping saves are followed by checked reads. A later suggestion remains distinct from the earlier explicit high-water record, while the installation epoch and saved preferences stay correct.
3. Six independent cases use different valid state bytes from a second real P1 store, missing state, a replaced named lock, a detached namespace, a replaced namespace and an unexpected entry. Each actual checked read throws. After restoring the original fixture, both the checked read and a real preference-write attempt throw `poisoned`; the restored fingerprint remains unchanged. The cached compatibility property stays unchanged, but it is never returned by a successful checked read after tampering.

The original owner stays alive during each replacement/restoration case, preserving the relevance of held descriptors and identities. Tests do not access production recording or owner data. No test substitutes a parallel validation model for the production method.

## Execution evidence

| Inspected evidence | Verified result |
| --- | --- |
| `01-tests-first-red.log` | Expected missing-member compilation failure for `PracticeSetupStore.checkedSnapshot`, retained before the wrapper existed. The preserved `01-tests-first.swift` is byte-identical to the final test file. |
| `03-frozen-focused.log` | **15 tests in 1 suite passed**, 0.133 seconds; includes all three new functions and all six tamper cases. |
| `04-frozen-core.log` | **245 tests in 19 suites passed**, 169.401 seconds. All new checked-read tests pass; the existing transport suite also passes. The prior O3c result was not carried across the P1 change. |
| `05-frozen-phone-release.log` | `PadelStrokeLab` Release build succeeded, generic iOS Simulator. |
| `06-frozen-watch-release.log` | `PadelStrokeLab Watch App` Release build succeeded, generic watchOS Simulator. |

The toolchain evidence identifies Xcode 27.0 `(27A266a)` and OS 27 SDKs. The local evidence records explicit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; both Release logs identify the executable within that installation and OS 27 arm64/x86_64 simulator targets. Focused and full-core logs have no warning/error diagnostic. Both Release logs have successful terminal markers, no error diagnostic and four existing App Intents metadata-extraction warnings in total. The expected tests-first red is preserved; the evidence records no later failed/retried run.

After both builds, the reviewer reverified all current and archived source hashes, embedded manifest and all ten evidence hashes. The read-only `git diff --check` returned zero. These are host synthetic-fixture tests and simulator compilation results, not physical-device, paired connectivity, UI, sensor, background, battery or arm64_32 evidence.

## Boundaries for the next package

O4p exposes existing P1 live validation only. P1's held-base behavior is unchanged; the separate canonical-base/witness/namespace checks remain O4a work. O4a may rely on this exact checked-read API after director acceptance, while preserving all Core inputs. It must not reinterpret a checked P1 snapshot as authority.

O4b's independent practice identity, current-versus-next state, relaunch and End design gate remains open. This review does not approve those lifecycle choices or authorize a new persistence journal. Neither successor package is released by this report alone.
