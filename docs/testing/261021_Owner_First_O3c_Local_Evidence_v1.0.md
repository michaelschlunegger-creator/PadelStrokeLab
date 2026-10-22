# Owner-first O3c — completion-counted transport evidence

Date: 2026-10-21. Implementation: GPT-6 Astra / Extra High, selected for asynchronous transport, cancellation and persistence ordering. Independent review is separate and read-only.

Status: exact final source frozen; core and both Release builds PASS; independent final closure pending. This is local package evidence, not merge/release or physical-connectivity approval. O4 requires the director's separate release.

## Identity and scope

- Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`.
- Branch: `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; intentionally extensive unpublished working tree, no upstream. No commit, push, PR, merge, installation, simulator mutation or personal-data access/deletion in O3c.
- Authority: approved owner-first first-build contract and `261021_Owner_First_O3_Sequencing_Amendment_v1.0.md`; director released O3c after accepting frozen O3b.
- Production: only `Packages/PadelCore/Sources/PadelCore/RecordingConnectivity.swift`, 400 added / 16 removed = **416 changed lines**, within the 600-line cap; 918 total lines.
- Tests: new `Packages/PadelCore/Tests/PadelCoreTests/OwnerPreparationTransportTests.swift`, 503 lines, 18 test functions including two two-case parameterized functions. Existing `RecordingConnectivityTests.swift` is unchanged; its shared admission/background/raw regressions run in the full suite.
- All **78 other predecessor source/test/config files** match the accepted 79-entry O3b manifest exactly. O1/O2/O3a/O3b production/tests and all app/UI code remain frozen. Final O3c manifest has **80 entries**.

## Transport and completion contract

The existing sole WCSession delegate now routes wire2 interactive requests/replies, draft-only application context and queued owner mutate/transition/acknowledgement controls. The original raw-file and `PSLReceipt1` receipt transaction paths are retained. The extracted `receiveUserInfo` bridge is the production delegate path exercised by host tests, including valid controls, invalid payload/kind rejection and actual retained-archive receipt verification. The host adapter replaces only native send operations; public construction uses real WCSession.

Raw jobs and owner operations share the existing 16-operation admission count. An outbound operation keeps its original lease while awaiting its native callback and then while its configured asynchronous reply handler performs local mirror/prune/persistence work. There is no release/re-admit gap. Duplicate native callbacks are claimed once. Caller completion, timeout and cancellation do not release an outstanding native callback or active handler. If a native callback never arrives, its bounded lease remains occupied and background drain cannot report success; the drain request itself can expire false. No forced-success cleanup is inferred.

`OwnerPreparationWork.commit` is a synchronous, single-use, explicitly non-reentrant final gate. It checks cancellation and the actual monotonic deadline inside the gate before mutation. A delayed owner-queue timer cannot authorize an expired commit. Concurrent cancellation waits for an already-entered synchronous commit; same-thread cancellation defers its observer callback until the commit closure exits. A callback may therefore finish while post-commit asynchronous handler work remains suspended; the lease still belongs to that handler until its real return. Repeated or escaped commits fail. Shared-state locks are released before work gates and external completion callbacks.

One latest draft is retained in each direction, including when all 16 work slots are occupied. An active inbound draft keeps its lease while superseded work finishes, then atomically hands it to the latest pending draft. Older pending drafts are cancelled. Outbound changes coalesce before native context submission; timer setup also coalesces, so blocked owner queues do not accumulate per-edit timer tasks. Pending drafts prevent a false background-drained gap. Native queued owner controls are bounded and exact-payload deduplicated. Queue/context submission success means **submitted/pending**, never remote authority application or Watch Start authority.

## O4 integration obligations

- Share the already-existing connectivity instance; never introduce another WCSession delegate or independently opened O2/O3b owner.
- Configure the owner handler before WCSession activation, or retain explicit recoverable pending/retry semantics for arrivals before handler availability.
- Keep the channel on one non-main serial executor. Revalidate the current peer, generations and authority and perform synchronous persistence inside `work.commit`; await all mutation work inside `onOwnerPreparation` before returning. An observer callback is not a persistence handoff and must not launch uncounted mutating tasks.
- Call synchronous `cancelOwnerOperation` off the main actor because it can wait for persistence/fsync inside an entered gate. Cancellation/timeout is observational and may follow a committed local or remote mutation. It never proves authority unchanged, clears an O3b dispatched intent, or substitutes for an exact channel acknowledgement.
- App adoption, owner enrollment UI, Watch admission, HR access and device behavior are outside O3c.

## Exact source and checkpoints

All private artifacts are under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/`.

| Artifact | SHA-256 / role |
| --- | --- |
| `docs/testing/261021_Owner_First_O3c_Source_v1.0.sha256` | `94c51aca7a4f72669935eb7a17394f54900f6704fbe908ddc21ed9c7c6a4fc15`; final 80-entry manifest |
| `O3c/07-source.sha256` | Exact private copy of the final manifest |
| `Checkpoints/03c-o3c-source-v1.1.tar` | `8d5099334adeddb9b57d943bf28025c6a7a33c143dff3d6f94c29b241081fb79`; final source and embedded manifest |
| `O3c/05-source.sha256` | `0edbf86cbe9715c66d43d26ece68a7de50f5ba67f2d04f9fe421c8a476b337bf`; superseded first freeze, retained for failed run 06 |
| `Checkpoints/03c-o3c-source.tar` | `f3df6ace455a23a485130f06c37a701910b2dc2962ec6494e72bdfbdd553b685`; superseded first freeze retained unchanged, including its embedded manifest |

Final production SHA-256: `f917652863474eb8345728c9e74085fe2d9ff750ec44838a21721ccf04258917`. Final transport-test SHA-256: `97dffdac374768eb8e6a073b00c09565eea9c392fbeecfa71b7160251e006ceb`.

## Runs and preserved failure

| Private O3c artifact | Result and applicability |
| --- | --- |
| `01-tests-first-red.log` | Expected missing-API compile failure before production implementation: `OwnerTransportAdapter` absent. |
| `02-initial-implementation.log` | PASS — 8 initial focused test functions on the preliminary implementation. |
| `03-expanded-regressions.log` | PASS — 16 focused functions; superseded by timer-start coalescing and review regressions. |
| `04-review-regressions.log` | PASS — 17 focused functions, including absent native callback through cancel/timeout; superseded by later docs/control-bridge/harness changes. |
| `05-source.sha256` | First frozen 80-entry source, mapped to run 06 and the first retained checkpoint above. |
| `06-frozen-core.log` | **FAIL — 242 tests / 19 suites, 23 issues**, 163.031 seconds. 22 issues in 8 transport test functions; one issue in existing `deletionWaitsForImportThenWithholdsAckAndPreventsResurrection`. Preserved completely. |
| `07-source.sha256` | Final successor source, mapped to runs 08–10 and the distinct v1.1 checkpoint. |
| **`08-frozen-core.log`** | **PASS — 242 tests / 19 suites**, 179.101 seconds; final 18 transport functions passed in 10.161 seconds, including all parameterized cases. |
| **`09-frozen-phone-release.log`** | **PASS**, scheme `PadelStrokeLab`, Release, generic iOS Simulator 27. |
| **`10-frozen-watch-release.log`** | **PASS**, scheme `PadelStrokeLab Watch App`, Release, generic watchOS Simulator 27. |

The initial focused cases completed in less than 0.4 seconds. In run 06, unrelated transport cases simultaneously held real synchronous owner queues and a commit gate while the broader suites exercised disk/receipt barriers. Whole-suite scheduling delays exceeded the unchanged 5/10-second safety bounds, and the 80 ms applied-reply deadline could expire before its handler started. Symptoms included timedOut instead of cancelled, held raw slots expiring before overflow assertions, and one frozen legacy 10-second receipt barrier missing its signal. Independent review inspected this trace; the director explicitly ratified serializing **only the new transport suite**. Every within-case 16-slot concurrency/overflow/drain assertion and existing deadline was retained. No frozen legacy test or production algorithm was changed for the failure. Final run 08 passed those same assertions and the legacy suite. This is a documented harness scheduling correction, not a claimed product-defect fix or unexplained retry.

Before the final successor freeze, review also corrected the two cancellation comments and the reentrant regression to hold a real post-commit handler phase, distinguishing observer completion from handler completion. Two unused-return warnings in test failure sentinels were removed with explicit `_ = try`; final core has no warning diagnostic. Preliminary focused/full logs retain those historical warnings. No failed run was hidden or automatically retried.

## Toolchain, commands and limits

Every Swift/Xcode command used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and the executables inside that installation. Verified Xcode 27.0 `(27A266a)` with iOS/watchOS 27.0 device and simulator SDKs. No global selection or toolchain upgrade occurred.

- Core: `swift test --package-path Packages/PadelCore --scratch-path <OwnerFirst>/O3c/SwiftBuild`; preliminary focused runs added `--filter OwnerPreparationTransportTests`.
- Phone: `xcodebuild -project PadelStrokeLab.xcodeproj -scheme PadelStrokeLab -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath <OwnerFirst>/O3c/PhoneRelease CODE_SIGNING_ALLOWED=NO build`.
- Watch: `xcodebuild -project PadelStrokeLab.xcodeproj -scheme 'PadelStrokeLab Watch App' -configuration Release -destination 'generic/platform=watchOS Simulator' -derivedDataPath <OwnerFirst>/O3c/WatchRelease CODE_SIGNING_ALLOWED=NO build`.

After both builds, all 80 current source/checkpoint entries and both embedded manifests were reverified. The 10 private evidence entries were hashed; source/test trailing-whitespace checks and `git diff --check` passed. Independent closure remains pending. Both Release logs contain only four existing App Intents metadata-extraction warnings in total for targets without that dependency; no new Swift/error diagnostic remains. No physical sensor/connectivity/background/battery/wearer behavior is proved by host tests or simulator compilation.
