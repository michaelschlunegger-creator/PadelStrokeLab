# Owner first build O2 — local evidence v1.0

21 October 2026. Implementation: GPT-6 Astra, Extra High reasoning. This is the released exclusive owner-persistence package, not the completed first build, live capture, complete transfer/deletion, or merge readiness.

## Exact scope and source

Director release follows accepted O1 and the unchanged [first-build contract](261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md), SHA-256 `f7666a8d73d5e11fa786571f294b9837d96d3768b30d9318b578ab8d762f706f`. Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, intentional unpublished changes/no upstream. No Git publication, installation, simulator mutation or personal-data access occurred.

O2 adds only `Packages/PadelCore/Sources/PadelCore/OwnerPracticeStore.swift` (**661 production lines**, cap1,200) and its matching new `OwnerPracticeStoreTests.swift` (463 lines). The two domains are persistence and provenance. All73 accepted O1 source/configuration/test inputs remain byte-identical, including all four O1 production/test files and frozen P1. No existing source, test, build configuration, permission, raw-format or application file changed.

The [75-entry final source manifest](261021_Owner_First_O2_Source_v1.0.sha256) has SHA-256 **`29440c97a96b96eb70faf99c072f508a5b62f433f2f102f05ce0ab675e2265f9`**. Complete source contents plus that manifest are preserved at `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/Checkpoints/02-o2-source.tar`, SHA-256 **`61cd5ed2ebd2e57e58668e4ee76199cd788a5f2cc22534711432c2d05e00d5dc`**. Earlier checkpoints remain unchanged. The source manifest was checked before and after the final runs; `git diff --check` passed.

## Evidence and retained failures

Raw logs are under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O2/`; `evidence.sha256` identifies their exact bytes. Build products and synthetic fixtures are outside the repository. Every Swift/Xcode invocation set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Toolchain recheck returned Xcode27.0 (27A266a) with installed iOS/watchOS27.0 SDKs. Latest-patch/Xcode27.1 compatibility remains untested.

| Attempt | Result and significance |
| --- | --- |
| `01-tests-first-red.log` | Expected exit1: tests referenced missing owner-store types before production implementation. |
| `02-focused.log` | PASS11 focused tests on the initial implementation. Superseded by membership and initialization corrections. |
| `03-membership-red.log` | FAIL13 tests/seven issues: removing a committed replay guard or reserved context directory could make protected identity membership disappear. The independent reviewer identified the missing durable inventory binding. |
| `04-membership-recovery.log` | Compile failure: the second throwing guard lookup lacked `try`. Corrected explicitly; no assertion was weakened. |
| `05-boundaries.log` | PASS20 focused tests after the membership journal, explicit open/create intent and descriptor-ownership corrections, including real full-capacity storage. Two additional focused corruption/temporary-state tests followed. |
| `06-source.sha256` | Exact private copy of the final75-entry source manifest above. |
| **`07-frozen-core.log`** | **PASS179 tests/16 suites**, including22 unique O2 tests, on final source. Parameterized cases exercise real filesystem failure boundaries and both inventory limits. |
| **`08-frozen-phone-release.log`** | **PASS**, `PadelStrokeLab`, Release, generic iOS Simulator. |
| **`09-frozen-watch-release.log`** | **PASS**, `PadelStrokeLab Watch App`, Release, generic watchOS Simulator. |

No failure was hidden or automatically retried. All corrections and subsequent assertions remain in the two O2 files. The final Release logs compile `arm64` and `x86_64`; they are simulator compilation evidence, not physical execution or `arm64_32` validation. Both builds contain only the existing App Intents extraction warning for targets without an AppIntents dependency; no new Swift diagnostic remains.

Core command: `swift test --package-path Packages/PadelCore --scratch-path <O2>/SwiftBuild`; focused runs add `--filter OwnerPracticeStoreTests`. Builds use `xcodebuild -project PadelStrokeLab.xcodeproj -scheme <scheme> -configuration Release -destination 'generic/platform=<iOS Simulator|watchOS Simulator>' -derivedDataPath <O2>/<PhoneRelease|WatchRelease> CODE_SIGNING_ALLOWED=NO build`. Both executables were invoked by their absolute paths in the approved Xcode installation. The final full suite and two builds used separate scratch/DerivedData directories and did not launch or mutate a simulator.

## Implemented behavior

`OwnerPracticeStore` is a synchronous, intentionally non-Sendable exclusive owner. Later integration must confine it to one serial worker/actor. It owns `OwnerPractice-v1` separately from raw `Recordings`, uses descriptor-relative no-follow access, an exclusive lock, regular single-link files, bounded enumeration and inode/device ownership revalidation, and never visits or rewrites raw recording directories. Initializer validation completes before descriptor ownership transfers to `self`, preventing error-path double close.

Initialization requires an explicit `.createNew` or `.openExisting` intent. Create refuses an existing namespace; open never creates a missing one. Exact device role and local installation epoch must match durable state. Later app integration must retain initialization evidence outside this namespace and use `.openExisting` for known installations, even when the namespace has disappeared. The store cannot infer history after erasure of the whole app container; explicit new-installation provenance remains a separate integration decision.

The strict canonical checksummed state is bounded at16KiB and retains authority plus count/SHA-256 membership for at most512 context/failed-ID entries and1,024 minimal replay guards. A single pending reservation is included in those bounds. State never contains an unbounded separate inventory. Membership removal/addition fails closed before normal operations, including after process reopen; capacity is refused without eviction or authority reset. Maximum128-decision O1 history also persists and reopens within16KiB.

Reservation transaction order is: persist the pending identity with unchanged committed authority; create/synchronize only an empty directory or zero-byte guard; persist updated membership and clear the pending reservation. Context payloads are written only after this reservation finalizes. Interrupted pending reservations recover only absent/empty context stubs or absent/regular zero-byte guard stubs. Unexpected payloads, symlinks and hardlinks fail closed. An exact single-reservation `state.pending` transition may be retained conservatively only when all committed authority/epoch/schema/membership bytes are unchanged. No uncommitted consent or context payload is promoted. Other valid unacknowledged state candidates are discarded after committed-state validation; malformed temporary state remains preserved and blocks opening.

Authority replacement uses synchronized temporary bytes, atomic rename and parent-directory synchronization. The in-memory snapshot changes only after durable checks. Ambiguous write failures poison the current owner; reopening reconciles committed bytes. Guard publication precedes acknowledged authority advancement, so interruption may conservatively block an identity while retaining the earlier committed authority revision. An idempotent guard operation synchronizes its zero-byte file and directory again before acknowledging. Only `ENOENT` can mean an absent guard; other lookup errors fail closed.

Each context directory retains the exact validated canonical raw metadata copy and immutable O1 context. Its publication uses synchronized temporary files and no-overwrite publication, with explicit partial/corrupt/retired inspection. A failed reserved ID cannot become fresh. Fresh versus existing receipts are privately constructed and carry store/publication identities, exact context digest and validated authority revision. Duplicate publication revalidates current exact consent/authority and replay guards and re-synchronizes the payload before acknowledging. Neither receipt permits Start or proves raw samples, wearer identity, terminal-tail completeness, or full-practice companions.

## Coverage and integration obligations

Tests exercise fresh explicit enrollment and disk reopen; wrong device/epoch; competing ownership; absent known namespace; base and namespace replacement; deleted lock/state/context/guard roots; symlink/hardlink/oversized/truncated/unknown context payloads; invalid/uninitialized/malformed state; current consent and stale/conflicting bindings; exact duplicate receipts; recording/practice replay guards; withdrawal persistence; all state publication/synchronization boundaries; reservation and finalization boundaries; guard/context interruption; conservative stub recovery; poisoned owners; missing committed membership; actual full512/1,024 limits including failed last slots; maximum consent history; and unchanged raw sibling bytes. These use synthetic data and actual production storage paths.

O9 content deletion must remove all metadata/context/pending payloads while retaining the empty immutable recording-ID reservation directory and minimal replay guard. The empty ID stub is non-content replay protection, not retained context data. Removing that reservation directory itself is corruption. Full raw/HR/label/derivative/export cleanup, leases and paired acknowledgements remain O9 work; this package performs none of those deletions.

O3–O5 must consume the opaque publication receipt and exact persisted authority without treating disk publication as admission. They must invalidate pending Starts before asynchronous mutation, use only a newly published context for fresh capture, recheck all generations/physical confirmation and perform final admission without suspension. Explicit first-use/open behavior must survive integration. O6/O7 must implement and test backup exclusion before app telemetry/research/temp storage is adopted, as directed separately; no telemetry or app adoption is included here.

## Handoff

Final source/evidence are ready for separate exact-source O2 verification. The reviewer edits no files and runs no builds. O3 source may begin only after independent O2 clearance and director acceptance; O2 and every predecessor then freeze. Formal committed-HEAD G6 review, current hosted CI, relevant physical G7, user-authorized publication/merge and delivery of the complete owner first build remain open.
