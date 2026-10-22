# Owner-first O4 sequencing amendment v1.0

21 October 2026. Author: GPT-6 Astra / Extra High. Proposed for independent review and director ratification; **no O4 production or test change is authorized by this document alone**. O3c is accepted on its exact 80-entry manifest `94c51aca7a4f72669935eb7a17394f54900f6704fbe908ddc21ed9c7c6a4fc15`.

## Reason and unchanged boundary

Frozen O3b requires durable first-use evidence outside both owner namespaces. P1 supplies installation identity and preference storage, but absence of P1/O2/O3b together cannot distinguish first use from loss of an initialized triplet. A small external witness is necessary. P1's public snapshot is cached; its existing private live check needs a minimal read-only public wrapper before bootstrap can verify both stores without artificial writes or duplicating their private validation. Implementing descriptor-relative bootstrap persistence together with authority and asynchronous UI would exceed the original O4 two-domain boundary. Split O4 before implementation; preserve the original **1,700 changed production-line budget**.

| Package | Allowed source and hard cap | Risk domains and tests |
| --- | --- | --- |
| **O4p — checked P1 read prerequisite** | Existing `Packages/PadelCore/Sources/PadelCore/PracticeSetupStore.swift`; at most **10 changed production lines**. | Live persistence/ownership validation through existing code only. Existing `Packages/PadelCore/Tests/PadelCoreTests/PracticeSetupStoreTests.swift` only. No parser, write, authority or app change. |
| **O4a — deny-only phone bootstrap** | NEW `PadelStrokeLab/OwnerPhoneBootstrap.swift`; one production file, at most **250 lines**. | Bootstrap persistence and exclusive ownership. NEW app-host `PadelStrokeLabTests/OwnerPhoneBootstrapTests.swift`. No UI/app adoption or connectivity activation. |
| **O4b — phone setup and UI** | Original NEW `PadelStrokeLab/PracticeSetupModel.swift`, `PracticeSetupView.swift`; existing `ContentView.swift`, `PadelStrokeLabApp.swift`, `RecordingLibraryModel.swift`; five production files, at most **1,440 changed lines**. | Preparation authority and asynchronous UI state. NEW app-host `OwnerPracticeSetupTests.swift`, UI `OwnerPracticeSetupUITests.swift`; only currently declared existing test change is `PadelStrokeLabUITests/PadelStrokeLabUITests.swift` for directly affected home/guide navigation. Additional existing-test scope must be declared before edits. |

Only O4p may change its two explicitly listed Core files; all other Core, Watch, configuration, signing, raw-file, guest, Health acquisition, remote Start and unrelated UI changes remain forbidden. No budget pooling or hidden helper files. Existing synchronized Xcode groups require no project-membership edit. Tests precede implementation; preserve every red/failure. Each package requires its own freeze, test, independent review and director acceptance before the next package is released: **O4p → O4a → O4b**. The O4p source replaces only those two entries in the accepted source inventory; O3c and every other predecessor input stay frozen.

## O4p API, tests and evidence

Add only `public func checkedSnapshot() throws -> PracticeSetupPersistentState`, calling the existing private `checkLive()` and returning `snapshot`. It performs no write, parser/codec change, new recovery, grant or acceptance. Preserve cached `snapshot` compatibility and all existing validation and sticky-poison semantics. Do not reproduce P1's private validation in bootstrap or mutate preferences merely to validate them.

Before this wrapper exists, add meaningful regression tests in the existing P1 test file and preserve the expected missing-member failure. Verify healthy repeated checked reads preserve bytes, inode and modification time of the state and lock files and namespace directory; a checked read after actual saved preferences/suggestion/explicit-bookkeeping operations returns their correct current state. Independently replace the backing state with different valid bytes, remove it, replace the lock, detach/replace the namespace, and add an unexpected entry. Each rejects through the real checked read, remains poisoned after the original fixture is restored, and never returns the cached state as current. Fixtures are isolated synthetic directories; no production data is accessed or changed.

Run focused P1 tests, full core regression and both OS27 Release builds with installed Xcode27.0 `(27A266a)` after the exact O4p source/test freeze. Preserve source manifest/checkpoint, initial red and every later failure, logs, changed-line count and independent review. The previous core242/19 result cannot be carried over the P1 change. Director acceptance of this exact O4p package is required before any O4a source/test edit. This amendment's review alone does not release Core changes.

## O4a API and ownership

`OwnerPhoneBootstrap` is a synchronous, intentionally non-Sendable owner, constructed and used on O4b's non-main serial executor. It retains the witness descriptor/lock and **one P1 `PracticeSetupStore` plus one O3b `PracticeSetupChannel`** for its lifetime. The channel privately owns O2; callers never separately open O2. No public writable snapshot or store escape is added.

A synchronous checked `withStores<T: Sendable>` operation provides nonescaping access to the two existing stores and returns only Sendable results. Each call verifies the witness, its named/base identity and all three captured namespace directory identities, then invokes P1 `checkedSnapshot()` and O3b `readSnapshot()`, before and after the body. Post-verification runs on both success and throw; a failed ownership/integrity check takes precedence. If checks pass, return the result or rethrow the body's original domain error. Bootstrap verification/write failures poison the bootstrap; body errors retain each accepted store's own poison semantics. In particular, an expected `intentOutstanding` can persist a local fence without disabling later resolution; a successful post-check preserves that fence and rethrows the original error.

O4b keeps the bootstrap private and does not retain/copy either store outside that closure. The bootstrap does not sequence, mirror, request or grant authority itself. Its only writes are its witness and the existing stores' first initialization through their frozen APIs. It never repairs or recreates missing storage.

The caller supplies the canonical app-support base used by `RecordingPaths`, **outside `Recordings`**. It is the parent of that raw namespace, not `notesRoot`; P1 explicitly rejects a base beneath `Recordings`. The bootstrap opens the base by a descriptor-relative no-follow directory traversal and verifies its identity when used.

After checked construction, retain the device/inode identities of the three named namespace directories. Every live pre/post-verification uses the held base descriptor and no-follow metadata reads to require the same directories, rejecting replacement/detachment/symlinks; it also reopens the canonical base path to detect a detached base. These are namespace-ownership checks, not substitutes for store validation. P1 `checkedSnapshot()` validates through its existing private live check; O3b `readSnapshot()` validates its channel and privately owned O2. No duplicate parser, private file codec, artificial preference mutation or externally owned O2 is added. A cached P1 `snapshot` does not prove current backing-file integrity or acceptance, and even a checked P1 read grants no authority.

Exact sibling names are:

- Witness: `OwnerPhoneBootstrap-v1` (a regular file).
- P1: `PracticeSetup-v1`.
- O2: `OwnerPractice-v1`.
- O3b: `OwnerChannel-v2`.

## Witness format and write order

The witness is a fixed UTF-8 format, at most 128 bytes. Accept only exact bytes and a canonical UUID spelling. It contains no owner ID, peer epoch, consent, preference, accepted preparation, recording or human identity.

```
PSLPhoneBootstrap1
pending
```

After successful initialization, its exact content is:

```
PSLPhoneBootstrap1
ready
<canonical P1 localInstallationEpoch UUID>
```

Both forms end in one newline. The UUID is only a cross-check against P1 and O3b's existing installation epoch; the witness cannot reconstruct it if either store is missing.

1. Inspect the witness and all three sibling namespaces with no-follow checks. An absent witness is eligible for first initialization **only when all three namespaces are absent**. Any existing namespace without its witness blocks initialization and is preserved.
2. Create the witness with exclusive creation/no-follow; require a regular single-link file within the byte bound; acquire an exclusive nonblocking `flock` on its descriptor. Persist exact `pending` bytes, synchronize the file and parent directory, and recheck named identity **before creating any store namespace**.
3. Construct P1 with its existing API. Use its durable `localInstallationEpoch` to construct O3b with device `.phone` and `.createNew`; O3b alone constructs O2. Neither operation enrolls an owner or grants consent.
4. Only after both existing initialization APIs have completed durably, write/truncate/synchronize exact `ready` bytes and recheck the file/base identities. The witness remains at the same inode so its held lock is not detached by a rename. A short/torn write is never interpreted as readiness.
5. On reopen, require an existing valid `ready` witness and all three namespaces. Hold its exclusive lock, synchronize the loaded witness, open P1, compare its epoch to the witness, then open O3b with `.openExisting` and that same epoch. Use existing checked recovery in P1/O3b; never upgrade a `pending` witness or repair a missing namespace.

Any invalid/missing epoch, pending/partial/corrupt witness, absent/partial/corrupt initialized namespace, symlink, non-regular/hard-linked file, detached/replaced named identity, lock contention or I/O ambiguity fails closed. No grant, reset, deletion, namespace recreation or migration follows. A valid completed ready file can be synchronized and checked on reopen; an incomplete readiness transition may remain blocked and require separately approved recovery. Do not present such state as a fresh install.

The witness is **deny-only**: its presence can prohibit reinitialization, but cannot restore authority or permit recording. First enrollment still requires fresh explicit owner attestation and motion-study consent bound to the actual observed peer; any HR grant remains separately affirmative. A foreign existing Watch peer cannot silently enroll, replace an identity or import its status as authority.

## O4a tests and evidence

Exercise actual production file/store paths in isolated synthetic app-host fixtures, including:

- First initialization creates one ready witness and a checked empty phone channel; epoch stays identical on healthy reopen; authority remains nil.
- Faults after pending file/parent synchronization, after P1 initialization, and after O3b initialization but before ready publication leave preserved fail-closed state. Hooks observe those actual boundaries and default to nil in production.
- Pending, truncated/partial ready, unknown version, malformed/noncanonical/wrong epoch, oversized witness, and complete triplet loss while the external witness survives never recreate an installation or owner.
- Each missing/corrupt initialized namespace, existing namespaces with missing witness, and an existing foreign-role/epoch channel are rejected without modifying prior evidence.
- Concurrent second owner, witness/path symlink, hard link, non-regular file, base/witness replacement and detached namespace fail. Retain first owner until its rejection checks finish; do not assert inode history after all owners close.
- Verify pre/post checks use both actual checked store APIs, and that a body which throws still receives the post-check: tamper then throw rejects and poisons, while an unchanged healthy body error is preserved. Exercise an O3b conflicting restriction that durably raises its local fence and throws `intentOutstanding`; verify the fence survives and the healthy bootstrap remains usable for explicit resolution.
- Check no raw archive/recording mutation, no authority grants, no automatic cleanup and no silently healed partial initialization.

Run the relevant app-host bootstrap tests and both OS27 Release builds on the exact frozen O4a source, using the explicitly selected installed Xcode27.0 `(27A266a)`. The accepted O4p full-core result can carry forward only while every package input is exact; rerun affected core evidence if that premise changes. Preserve manifest/checkpoint, logs, failures, reviewed scope and independent package verdict before requesting O4b release. No synthetic UI launch is needed for O4a. App-host simulator tests use only the director-reserved OS27 pair and isolated fixture directories; no erase/uninstall/default/personal-data mutation.

## O4b retained safeguards and limitations

O4b shares the sole existing connectivity instance and installs `onOwnerPreparation` before activation. It owns the bootstrap on its non-main executor; every reply mutation is awaited inside the original counted handler and final synchronous `work.commit`. Peer/generations/current authority and exact pending affirmative decisions are checked there. Synchronous cancellation runs off the main actor and never clears dispatched intent or proves authority unchanged.

Main-actor edits, End and withdrawal immediately invalidate presentation or raise the local privacy fence before an executor hop. Old status/preparation replies cannot publish accepted/current UI; required old dispatched authority transitions still reconcile without erasing a newer privacy fence. Pending/submitted, locally blocked and remotely applied remain distinct. Restored preferences/status/high-water do not grant consent or Start. Preserve the first-build contract's distinct identities: `practiceID` is independently created companion identity, never an alias or reinterpretation of P1's `preparationID`. Contexts retain both fields separately. Same-practice edits retain `practiceID` while draft revisions and preparation generations advance as required; a new practice after End uses a fresh `practiceID` and monotonic global draft revision. Test identity separation through edits, current-versus-next acceptance, relaunch and End retirement; relaunch cannot restore authority from P1. Persist only actual lifecycle facts through the existing accepted O3b/P1 APIs. If those APIs cannot durably represent a concrete required fact, surface that need for separate review before implementation; this amendment authorizes no additional journal or identity persistence.

Deletion of the **entire app container**, including the witness and all companion namespaces, or OS reinstall removes local evidence of the old installation. O4a cannot detect or recover that loss. Subsequent explicit enrollment creates a new provenance epoch; it must not relabel old recordings, restore prior consent or silently accept a foreign Watch identity. No Keychain, account migration, cloud identity or whole-container recovery is added by this amendment.
