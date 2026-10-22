# Black, turquoise and white — Icon B local evidence v1.0

21 October 2026, Asia/Dubai. Implementation and verification: GPT-6 Astra, Extra High reasoning. Branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Work remains local and unpublished.

**Status: LOCAL ICON B ACCEPTED, 21 October 2026.** Independent Astra Extra High review and coordinator direct checks found no remaining blocker in the bounded source/assets/build/simulator scope. Both native icons and normal launches pass, installed products match the built products, all eight original fixture files and Watch preferences are preserved, and the combined69-entry manifest matches. This is separate from formal G6, hosted CI, merge approval, physical collection, TestFlight and App Store release.

The pre-acceptance implementation report reviewed at SHA `016a16671de6a799d9abbacb701d22d27e4f74100f4e49fb0c57adafa141a32d` is preserved privately as `59-icon-report-before-director-acceptance.md`. This acceptance paragraph updates the reviewed report status; no code or test input changed.

## Authority and frozen scope

The director accepted local Theme A and explicitly released the ratified [Icon B contract](../design/261020_Black_Turquoise_White_Icon_Assets_Contract_v1.0.md), SHA-256 `c4d70894a4b8c444bc7b127204d5dd63f908518f0568eec45a23ad8e7a57d609`. Starting A38 manifest: 69 entries, SHA-256 `cd13839d9d34d820458ec1590c052d3a24c7ec936432bd17d743a59539e02d84`.

Exactly three implementation paths differ from accepted A38:

- `tools/generate_padel_master_icons.swift`: 15 changed source lines, seven exact palette/name substitutions.
- `PadelStrokeLab/Assets.xcassets/AppIcon.appiconset/PadelMaster.png`.
- `PadelStrokeLab Watch App/Assets.xcassets/AppIcon.appiconset/PadelMaster.png`.

The palette is charcoal-to-black `#1B272A` → `#050809`, white racket, charcoal openings, turquoise `#10D7CE` ball and `#041313` seam at the existing alpha. Every other generator byte, geometry statement, path, transform, stroke width, alpha/compositing operation, output path and both icon catalog JSONs remains unchanged. No app/test source, project configuration, identifiers, version/build, recording or transport behavior changed.

The [combined A+B source manifest](261021_Black_Turquoise_White_AB_Source_v1.0.sha256) was frozen immediately after generation and rechecked after verification: **69/69 match**. Manifest SHA-256: `9c69a73bb6031fefd26c82a16ef1ebefadda2c50573e33f7a5725720b4872ff0`. New evidence documentation is separate from the three implementation files.

## Rendering and Release evidence

All commands used `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; Xcode **27.0 (27A266a)**. Two independent Swift renderer runs wrote into isolated private roots. All four outputs are byte-identical before placement. ImageIO decoding verifies each is opaque, 1024 × 1024, `kCGColorSpaceSRGB`.

- Final PNG SHA-256, both platforms: `6d13eb93fff9aed2dd0f3ce070c34f96ba8a344e96d830756a372180be02aec8`.
- Final generator SHA-256: `a736fabff41b09f315405773a7d097b57509815b827fb271c6466f8e18a1a8dc`.
- `PadelStrokeLab`, Release, generic iOS Simulator: **BUILD SUCCEEDED**, `iphonesimulator27.0`.
- `PadelStrokeLab Watch App`, Release, generic watchOS Simulator: **BUILD SUCCEEDED**, `watchsimulator27.0`.

Both builds used `CODE_SIGNING_ALLOWED=NO` and the existing isolated DerivedData build directory. The phone build had no warnings; the Watch scheme logged only two routine AppIntents metadata-skipped warnings because no AppIntents framework dependency exists. Both products retain version 1.0/build 6. Compiled asset catalogs contain four phone and two Watch AppIcon entries; embedded and standalone Watch catalogs agree. Installed Info.plists, executables and asset catalogs match their respective built Release products.

| Installed product | Executable SHA-256 | Assets.car SHA-256 |
| --- | --- | --- |
| iPhone | `552c0adda542f48e3245833cf60a9deb92520f6f2358b75ddd7bc93e49c7601d` | `4fc2fa21081a0d8470478b62ddc872b80ad07db0470ae4a4505afc62ff29d899` |
| Watch | `189db4ecdac68264dc983131b696a2b3933349aca09f7e0aaf76f97d4d30da52` | `2e8213ac4a306b8c047cfe97cbc233cf218b7a11091de30cc9222a11f8354170` |

No behavior tests were rerun for this asset-only change. The [accepted Theme A report](261020_Black_Turquoise_White_A_Local_Evidence_v1.0.md) retains the applicable unchanged-source behavior evidence and its prior failures. Fresh Release and icon presentation evidence above supersedes prior app-asset evidence.

## Native presentation, failure and recovery

On the reserved iPhone 15 Pro iOS 27 simulator, the actual home-screen rounded-square icon shows the white racket and turquoise ball clearly at launcher size. The icon was opened normally into Practice. Portrait was used for the upright launcher capture, then the original landscape orientation with Dynamic Island on the right was restored.

On the reserved Watch Ultra 2 watchOS 27 simulator, the first launcher inspection still displayed the old blue/yellow icon after successful install. Reopening the app and returning to the launcher did not refresh it. Both failed observations are preserved. The installed `Assets.car` already matched the new built catalog exactly. One explicitly authorized restart of this reserved Watch refreshed its launcher; the native circular icon then displayed the new black/charcoal background, white racket and turquoise ball with essential geometry intact. No uninstall, erase, pairing change, version bump or source change was used. This supports a stale simulator launcher-cache explanation; it is not evidence about physical-device upgrade behavior.

The final ordinary Watch launch opens Practice. Final no-argument launch receipts record phone PID 73277 and Watch PID 74251. Neither app entered recording or setup during Icon B verification.

Phone restoration is verified: Dark appearance, text size 3, Reduce Motion/Increase Contrast/Reduce Transparency off, Capture Keyboard off, hidden software keyboard, Sound 0.6, landscape Dynamic Island right. Watch handedness/playing arm/intended drill remain **left/left/serve** by read-only preference verification. B did not change Watch text size; A's restored 2/9 evidence remains applicable. Watch Sound was observed at 0 before and after its restart. All **eight original protected synthetic files** still match the original pre-theme hashes. The frozen combined source manifest remains unchanged.

## Evidence locator and limits

Private evidence root: `~/Library/Developer/Xcode/DerivedData/PadelStrokeLab-TurquoiseTheme/`. Device Hub captures contain local sidebar device names and remain private; none were added to the repository.

| Evidence | Private files |
| --- | --- |
| Exact palette diff and baseline guard | `47-icon-palette-diff.patch`, `47-icon-source-edit-receipt.json` |
| Independent renders and decoded properties | `48-icon-render-a.log`, `48-icon-render-b.log`, `48-icon-decoded-properties.json`, `49-icon-generation-receipt.json` |
| Release builds and compiled catalogs | `50-icon-phone-release.log`, `51-icon-watch-release.log`, `52-icon-release-product-identities.json`, `52-icon-phone-assetutil.json`, `52-icon-watch-assetutil.json` |
| Actual iPhone launcher and restoration | `53-icon-phone-launcher-portrait.png`, `53-icon-phone-launcher-ax.txt`, `54-icon-phone-final-practice.png`, `54-icon-phone-restored-ax.txt` |
| Preserved stale Watch icon observations | `55-icon-watch-launcher-stale-before-refresh.png`, `55-icon-watch-launcher-after-app-return.png`, `55-icon-watch-cache-check.json` |
| Single Watch restart and corrected circular launcher | `56-icon-watch-restart-shutdown.log`, `56-icon-watch-restart-boot.log`, `56-icon-watch-restart-bootstatus.log`, `56-icon-watch-launcher-after-restart.png` |
| Final launches, identities, preferences and data guard | `57-icon-phone-final-launch.log`, `57-icon-watch-final-launch.log`, `57-icon-watch-final-practice.png`, `57-icon-final-restoration.json`, `57-icon-default-data-guard.json` |

Only the specified simulator launcher surfaces and ordinary launches were observed. No physical installation, App Store/account action, participant work, Git mutation or release-readiness claim is included. Independent final local evidence review and director acceptance are complete for the exact combined source manifest. Formal current CI/G6, relevant physical evidence and merge/release approval remain separate gates.
