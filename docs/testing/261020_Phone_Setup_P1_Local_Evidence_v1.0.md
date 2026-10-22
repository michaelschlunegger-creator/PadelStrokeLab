# Phone-led setup package 1 — local evidence v1.0

20 October 2026. Implementation author: GPT-6 Astra, Extra High reasoning, as requested for foundational code. This is a local bounded package result; independent review and later integration gates remain open. No transport, app/Watch flow, live capture, physical installation or Git publication was performed.

## Exact authority and source

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, no upstream. Live remote main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`, foundation `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, logger `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; draft PR 2 remains open for the existing logger, not this unpublished package. Current branch is ten commits ahead of remote main, zero behind. Existing intentional wizard/branding/documentation changes were preserved.

All 60 entries in the prior accessibility baseline remain byte-identical. New immutable local checkpoint: [64-entry source manifest](261020_Phone_Setup_P1_Code_State.sha256), SHA-256 `ca4332e66eaf46077a99df949d1d9d0d20895917c02af21db0fce24b64b15171`. It adds exactly two production and two corresponding test files. This is a private/local source checkpoint, not hosted-CI inventory or proof. Final integration package must update the workflow inventory separately.

Production scope: `PracticeSetupMessages.swift` 323 lines and `PracticeSetupStore.swift` 237 lines, **560 total**. New tests: 164 and 199 lines, **20 unique / 43 expanded cases**. None of the existing source, tests, schemas, project settings, signing, entitlements or workflow files was edited by package 1. Contract: [test contract](261020_Phone_Setup_P1_Test_Contract_v1.0.md). Ratification preceded tests and production edits; interim UI run 16 had completed and the baseline was frozen.

## Tests and preserved failures

Raw logs, commands, exit codes, before/after source copies and log hashes remain outside the repository at `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-PhoneSetup/contract`.

| Attempt | Exact result and disposition |
| --- | --- |
| `01-tests-first-red` | Expected compile failure: new message/store types absent. Tests were defined before new production files. |
| `02-first-implementation` | Compilation succeeded; 15 unique new tests ran, one failed. The accepted-next fixture incorrectly referenced the current draft in its correlation; strict production validation rejected it. Corrected fixture to the next draft, preserving the same intended assertion. |
| `03-additional-boundary-red` | 20 unique new tests; two failed with three assertion issues. New regressions exposed malformed directly constructed receipt matching and deleted ownership lock not checked before mutation. No retry or weakened assertion. |
| `04-full-core` | **PASS: 128 unique tests in 12 suites, zero issues**, including all 20 new tests. Fixes validate constructed request/reply before matching and recheck held-vs-named lock inode/type/link count before any store mutation. |
| `05-phone-release` | **PASS**, `PadelStrokeLab`, Release, generic iOS Simulator; isolated DerivedData. |
| `06-watch-release` | **PASS**, `PadelStrokeLab Watch App`, Release, generic watchOS Simulator; isolated DerivedData. |

All Swift/Xcode invocations used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, Xcode 27.0 (27A266a), iOS/watchOS 27 SDKs. Full core command was `swift test --package-path Packages/PadelCore --scratch-path <evidence>/core-build`. Release commands used `xcodebuild -project PadelStrokeLab.xcodeproj -scheme <scheme> -configuration Release -destination <generic platform> -derivedDataPath <separate evidence build path> CODE_SIGNING_ALLOWED=NO build`. Neither build booted or ran simulator/UI tests. Each build emitted two existing-style App Intents metadata warnings: extraction skipped because no AppIntents.framework dependency is present; there were no Swift compiler warnings/errors in the passing full-core/build logs. No physical-device evidence is implied.

The tests cover literal draft/error/discovery wire bytes, independent fixed digest, both-generation and exact-identity correlation, finite enums, all arms/manual drill values, unknown/extra fields/versions, duplicate/noncanonical JSON, bounds, unknown observation states, retirement generation rules, missing/reopened/corrupt/oversized state, no persisted consent/authority, monotonically increasing revision across preparation IDs, conflicting/duplicate identities, deliberate origin replacement, context-only suggestions, atomic pre/post-rename failure, poisoned ownership, pending crash residue, symlinks/hardlinks/missing/renamed paths, competing owner and bounded repeated writes. Synthetic recording sibling bytes and every original source entry are unchanged.

## Integration API and limits

- `PracticeSetupPreferences` and `PracticeSetupDraft` reuse `PlayingArm` and the ten existing manual `RecordingDrill` values. Drafts have origin installation epoch, preparation ID, epoch-wide monotonic revision and canonical digest. The digest is integrity/identity, not authentication. Manual intent remains development reference collection, not detection/training.
- `PracticeSetupMessage` provides draft/statusRequest/status/prepare/receipt/retire/error. `PracticeSetupCodec` accepts one canonical JSON form, max 8 KiB. `PracticeSetupCorrelation` always binds request ID, exact draft identity and **both** runtime/preparation generations. `isReply(to:)` validates structural semantics and correlation; phone must still invalidate obsolete requests/drafts and distinguish current from last-reported observations. Status discovery has a request ID and returns both current generations. Uncorrelatable input gets no invented typed error.
- `PracticeSetupStore(base:)` owns a separate `PracticeSetup-v1` child of an existing canonical app-support base, rejects a Recordings base, and holds an exclusive lock. `savePreferences`, `saveSuggestion` and `recordExplicitPreparation` persist only preferences/suggestion/high-water metadata plus local installation epoch. A suggestion never advances high-water. Same revision must match exactly; origin replacement defaults off and requires a deliberate explicit preparation path. Returned `.duplicate` means durable bookkeeping only, never accepted practice or a reusable receipt.
- Store file max 16 KiB; namespace permits only state, one lock and one bounded temporary. Writes synchronize temporary data, rename and synchronize directory before success. Pre-rename failure preserves old state; post-rename failure may preserve new state but throws and poisons the current owner. Reopen validates the whole checksummed canonical record. Existing namespace with missing state fails closed without repair. Deleting the entire namespace is indistinguishable from a new installation; fresh runtime generations and explicit preparation remain mandatory in either case. No automatic reset, expiry or restored authority exists.

Package 2 must provide the sole existing WatchConnectivity owner integration, actual live actor/generation/cancellation checks, completion-based admission, offline End/cancel retirement, current-vs-next ephemeral acceptance, and duplicates without renewed consent. Perform atomic bookkeeping before an acceptance acknowledgement, then revalidate cancellation/generations on the actor before sending success. No setup code in this package starts/stops capture or edits recording metadata. Watch placement and fresh per-set consent remain future integration responsibilities.

## Gate and next action

P1 scope and local deterministic tests/compilation are verified for the manifest above. Independent working-tree review is pending; formal committed-HEAD review, exact-HEAD hosted CI, full integrated app/UI regression and relevant paired physical observations remain open. The implementation author does not self-approve merge readiness. **Next: independent read-only P1 review, then the director's package-2 gate.** No code changes beyond P1 are authorized by this evidence document.
