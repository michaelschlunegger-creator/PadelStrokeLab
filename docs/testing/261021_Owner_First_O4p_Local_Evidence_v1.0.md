# Owner-first O4p — checked P1 read evidence

21 October 2026. Implementation: GPT-6 Astra / Extra High, selected for persistence-integrity and exclusive-ownership safeguards. Independent review is separate and read-only.

Status: frozen focused/full-core tests and both Release builds **PASS**; independent final closure and director acceptance pending. This is local package evidence, not G6, merge/release approval or physical-device evidence. O4a and O4b remain held until their separate releases.

## Identity and bounded change

- Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Intentional unpublished working tree; no upstream. No Git publication, app/UI test job, simulator mutation, device installation or personal-data operation occurred.
- Authority: director ratified the [O4 sequencing amendment](261021_Owner_First_O4_Sequencing_Amendment_v1.0.md), SHA-256 `e58ca5466a7d95dc367415106f0f8a0310eac71643afd75d699456c407314867`, and its [independent review](../reviews/261021_Owner_First_O4_Sequencing_Review_v1.0.md), SHA-256 `8fe7a08c934d2842662417bbd9ea1a7c71aa6aba93ad440b376f1974f142e852`, then explicitly released O4p only.
- Production: existing `Packages/PadelCore/Sources/PadelCore/PracticeSetupStore.swift`, **6 added / 0 removed lines**, within the 10-line cap; 243 total lines. One public throwing `checkedSnapshot()` calls existing private `checkLive()` and then returns `snapshot`.
- Tests: existing `Packages/PadelCore/Tests/PadelCoreTests/PracticeSetupStoreTests.swift`, **104 added / 0 removed lines**, 303 total lines; three added test functions, including one six-case parameterization. All pre-existing tests remain unchanged.
- All **78 other predecessor source/test/configuration inputs** remain byte-identical to accepted O3c. The resulting source manifest retains exactly 80 entries. No bootstrap, app integration, additional persistence, parser, write, authority or recovery change was made.

## Behavior and test proof

The new checked read reuses P1's existing directory identity, named-lock identity, entry validation, exact durable-state-byte comparison and sticky-poison behavior. It does not write, grant authority or restore acceptance. The cached `snapshot` property remains compatible but does not itself revalidate storage. P1's existing synchronous, exclusive, non-Sendable ownership contract remains unchanged.

- Fresh checked reads return the actual current empty state. Five repeated reads preserve the bytes, device/inode identity and modification timestamp of `state.json`, `.lock` and the namespace directory. The fingerprint includes the directory's complete current child list; access time is deliberately outside the immutability assertion because reading can update it.
- Actual `savePreferences`, `saveSuggestion` and `recordExplicitPreparation` operations are followed by checked reads of their correct state. A newer suggestion remains separate from the earlier explicit high-water record; epoch and saved preferences remain correct. Five repeated reads of this populated state preserve the same file/directory fingerprint.
- Six independent real-filesystem cases replace state with different valid checksummed bytes obtained from a separately initialized production P1 store; remove state; replace the held lock's named file; detach the namespace; replace the namespace; or add an unexpected entry. Each checked read throws instead of returning cached state. After restoring the original fixture, checked reads and a real write attempt still throw `poisoned`, with the restored bytes/identities/timestamps unchanged. The original owner remains alive throughout, so tests do not rely on persistent inode history after owners close.

This wrapper does not add canonical-base-path validation. O4a must provide that check, witness ownership and its own pre/post namespace checks while using this P1 API and O3b `readSnapshot()`. Existing store construction/reopen may still perform its previously accepted synchronization/recovery; O4p changes none of that behavior.

## Frozen source and private evidence

Private root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/`.

| Artifact | Identity / purpose |
| --- | --- |
| [O4p source manifest](261021_Owner_First_O4p_Source_v1.0.sha256) | SHA-256 `d2906f11be7e1c602bde308b80938c9b4e9fd6d28c2a963fd980a5c042c4aaf8`; 80 inputs |
| `O4p/02-source.sha256` | Exact private manifest copy |
| `Checkpoints/04p-o4p-source.tar` | SHA-256 `009f894249a51ff7dc3e35e28399b122d0e9b90c9ade36abbb4e57e3ab87f1ad`; source and embedded manifest |
| `O4p/evidence.sha256` | SHA-256 `30a59b37c64fab7902799b829f1e4166ed5ff0ef0aa38c78a9726a223d973c81`; all 10 private evidence entries |
| `O4p/02-PracticeSetupStore.swift.diff` and `02-PracticeSetupStoreTests.swift.diff` | Exact changes against the accepted O3c checkpoint |

Production SHA-256: `315e96b8c1653d6a9db6996b96aa149e8d5dc398986fc2110b8c221ae3ecc141`. Tests SHA-256: `d22fa724ac5664b55c03cb0b4a237d7f8cd688f2e48b2f25b1d1816303fe41c0`.

| Private O4p run | Result |
| --- | --- |
| `00-toolchain-and-state.log` | Xcode 27.0 `(27A266a)`, iOS/watchOS 27 SDKs, branch/HEAD and clean diff-check evidence |
| `01-tests-first-red.log` | Expected compile failure: `PracticeSetupStore` has no member `checkedSnapshot`; before the production wrapper existed |
| `01-tests-first.swift` | Preserved tests-first source, byte-identical to the final test file |
| `03-frozen-focused.log` | **PASS — 15 tests / 1 suite**, 0.133 seconds, including all six new tamper cases |
| `04-frozen-core.log` | **PASS — 245 tests / 19 suites**, 169.401 seconds; transport regressions also pass |
| `05-frozen-phone-release.log` | **PASS**, `PadelStrokeLab`, Release, generic iOS Simulator |
| `06-frozen-watch-release.log` | **PASS**, `PadelStrokeLab Watch App`, Release, generic watchOS Simulator |

The expected missing-member red is retained; there were no later test/build failures or retries. The focused and full core logs have no warning/error diagnostic. Both Release logs contain four existing App Intents metadata-extraction warnings in total for targets without that framework dependency; no new Swift warning/error remains.

## Commands and verification limits

Every Swift/Xcode command used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and executables within that installation. No global selection or toolchain update occurred. `<OwnerFirst>` below is the private root above.

- Focused tests: `swift test --package-path Packages/PadelCore --scratch-path <OwnerFirst>/O4p/SwiftBuild --filter PracticeSetupStoreTests`.
- Full core: the same command without `--filter`.
- Phone Release: `xcodebuild -project PadelStrokeLab.xcodeproj -scheme PadelStrokeLab -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath <OwnerFirst>/O4p/PhoneRelease CODE_SIGNING_ALLOWED=NO build`.
- Watch Release: `xcodebuild -project PadelStrokeLab.xcodeproj -scheme 'PadelStrokeLab Watch App' -configuration Release -destination 'generic/platform=watchOS Simulator' -derivedDataPath <OwnerFirst>/O4p/WatchRelease CODE_SIGNING_ALLOWED=NO build`.

The source freeze preceded focused/full-core and both Release runs. After both builds, all 80 current and archived inputs plus the embedded manifest were reverified, and `git diff --check` passed. Host tests exercise isolated synthetic directories. Builds prove compilation, not app adoption, live paired connectivity, sensor behavior, background behavior, battery, UI readiness or physical feasibility. The accepted O3c core result was not reused across this P1 change. O4a may carry this new core result only while all package inputs remain exact.
