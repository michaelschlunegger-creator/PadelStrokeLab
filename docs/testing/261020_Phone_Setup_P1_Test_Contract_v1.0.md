# Phone-led setup package 1 — contract v1.0

20 October 2026. Author: GPT-6 Astra, Extra High reasoning. Director ratified this focused package before source/test edits. Baseline: `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, immutable 60-file source manifest SHA-256 `1c7233b0b55ae2fdf29e8e48123b6caa5c6af6620e73ae4017f7c18f7f8450fe`. Interim UI run 16 finished before editing. Xcode 27.0 (27A266a), both OS 27 SDKs verified. Authority: PSL-SPEC-001 v1.1 §§6.3, 7.1, 16–18, owner amendments, phone-led plan v1.1 and ratification v1.0.

## Bounded scope

Only new `PracticeSetupMessages.swift` and `PracticeSetupStore.swift` production files, at most 2,500 lines; corresponding new core tests and this package's evidence/checkpoint. Two Level 3 domains: setup identity/metadata and bounded persistence. No existing source/test/project/workflow changes; no capture, transport, app/UI, raw recording schema, consent or remote Start implementation. No Git publication, device installation or release.

## Message contract

- Exact canonical UTF-8 JSON, version 1, separately namespaced `PSLPracticeSetup1.*` kinds: draft, statusRequest, status, prepare, receipt, retire, error. At most 8,192 bytes. Unknown/extra fields, unknown enums, noncanonical/duplicate-key input and unknown versions fail closed. Both endpoints use the same codec.
- A draft records sender installation epoch, preparation ID, epoch-wide monotonic integer revision 1…9,007,199,254,740,991, current racket arm, separate usual hand, and one of the existing ten manual development-reference drill values. Canonical digest uses existing SHA-256 helper, domain-separated canonical unsigned draft bytes; digest is integrity/identity, not authentication.
- Interactive preparation/retirement correlation binds request UUID, exact draft identity/revision/digest, runtime generation AND preparation generation. Every receipt/error echoes the full correlation. Initial status discovery binds request UUID; its Watch-authored snapshot includes both current generations. A retirement receipt additionally reports the resulting generation; correlation keeps the requested generation. No receipt replenishes physical consent.
- Watch snapshot has finite explicit unknown wrist/crown/capability/storage, finite nonnegative observation time, and separate accepted-current/accepted-next identity references. No ready/start or permission-success claim exists in the schema. A missing live recorder is unavailable with unknown observations and no acceptance references. These are transport data types, not authority validation.
- Malformed or uncorrelatable messages fail codec validation; transport must not invent a correlated error. Package 2 will enforce current generations, live actor, cancellation, admission lease and caller role before mutation.

## Persistence contract

- Dedicated `PracticeSetup-v1` child of an existing canonical app-support base; never use recording roots. No-follow descriptor-relative access, one exclusive store owner, bounded entries and bytes. Persist local installation epoch, optional preferences, latest validated draft suggestion and one high-water identity. Never accepted-current/next state, physical confirmation, per-set Start authorization or readiness.
- Revision increases across preparation IDs within one origin epoch. Equal revision requires identical identity/digest; older and conflicting revisions fail. Origin replacement requires an explicit deliberate flag; a context suggestion cannot silently replace it. A duplicate high-water result means durable bookkeeping only, never accepted practice or reusable acknowledgement.
- Atomic checksummed state replacement: write bounded temporary, synchronize file, rename, synchronize directory; success returns only afterward. Failure poisons the live store. Failure before rename leaves old state; after rename may leave new state, but no success/ack is returned. Reopen validates the surviving whole state; fresh runtime generations still require explicit delivery. Constant-size high-water and one temporary prevent unbounded tombstones.
- A newly created namespace initializes state. An existing namespace with missing state fails closed, including after relaunch; no silent defaults. Whole namespace deletion is indistinguishable from a genuinely new installation, so fresh runtime generations and explicit preparation remain essential. Corruption/oversize/unsafe path fail without overwriting evidence. No automatic repair/reset.

## Tests defined before production edits

1. Literal canonical wire bytes and digest; round trips for all kinds, arms and drills; exact identity and both-generation receipt correlation.
2. Invalid revision/digest/enums/version/fields/size/date, duplicate keys, wrong correlation and retirement generation transitions; absence of remote Start and physical-consent fields.
3. Fresh/missing/reopened state, preference/draft persistence without authority, exact duplicates, older/conflicting revision, monotonic cross-preparation IDs, explicit origin replacement.
4. Atomic injected pre-publish/post-publish failures preserve correct crash semantics and prohibit continued acknowledgement; real file corruption/truncation/oversize, missing-after-initialization, pending crash residue, symlink/hardlink/invalid base, competing owner.
5. Bounded repeated writes; recording sibling bytes and all original source entries unchanged.

Expected initial red: missing new types. Preserve every failed attempt, no retries/assertion weakening. Then new focused tests, complete core regression and both OS 27 Release compile checks in separate DerivedData, without simulator/UI jobs. Freeze a new local manifest, obtain independent working-tree review before package 2. These results cannot establish actual phone/Watch delivery, physical capture, UI acceptance, hosted CI or merge readiness.
