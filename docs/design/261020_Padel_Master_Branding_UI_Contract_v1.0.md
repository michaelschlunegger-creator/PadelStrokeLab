# Padel Master branding and UI contract

20 October 2026. Astra High author; owner-approved name and bounded Level 2 presentation work. Root approved this scope before implementation. Branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; preserve the complete uncommitted guided-setup package. App Store Connect record: Padel Master, Apple ID 6824907181, unchanged bundle `com.michaelschlunegger.PadelStrokeLab`, SKU `PADELTRAINER-001`. This is not publication, installation, merge or release authorization.

## Before-state and limits

The verified 57-file build5 manifest remains immutable at `docs/testing/261020_Guided_Padel_Setup_Code_State.sha256`, SHA-256 `208bc67b2f6017358ef13a559a6359a24f02bb7ab0159b8f9e45020a787b28b3`. Every entry matched before edits. Private `author/00-before-branding-source.tar.gz` preserves all 57 files and the manifest; `00-before-branding-hashes.json` records individual hashes. Evidence root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-PadelMaster`. Incremental diffs compare with that archive, not just Git HEAD.

At most eight production/config files and 2,500 changed text lines:

1. Phone `ContentView.swift`: Padel Master wordmark and VoiceOver label; restrained brand/hero refinement using the established palette and court.
2. `project.pbxproj`: four app display-name settings and version1.0/build6 only.
3. `Configuration/Watch-Info.plist`: replace the old brand in the existing Health-history explanation; meaning and permission keys unchanged.
4. Phone app-icon `Contents.json`.
5. Phone opaque 1024-pixel app-icon PNG.
6. Watch app-icon `Contents.json`.
7. Watch opaque 1024-pixel app-icon PNG.
8. Foundation workflow: new branding manifest reference only.

Existing phone UI tests may add meaningful visible-brand/no-old-brand checks; all previous assertions and 300-second execution bounds remain. A reproducible Swift/CoreGraphics development tool may generate the geometric icon from the existing court, blue, white and yellow design vocabulary. It is not an app dependency. No use of third-party marks or fabricated performance graphics.

Preserve all bundle IDs, target/scheme/product names, signing/team, entitlements, permission semantics, OS requirements, storage paths/preferences/protocols/data, capture/transfer/export/deletion behavior, fresh wizard rules and existing accessibility identifiers. Internal technical names and historical documents retain PadelStrokeLab. No Watch layout/theme/model changes and no new product features.

## Actual presentation inventory and design decision

Phone: Practice home; six-step practice guide; contact-reference guide; Sessions loading/empty/error/list; recording detail, add/edit attempt sheet, share/export and delete confirmation. Watch: landing, six mandatory preparation steps, native shot picker, capability blocker, capture/paused/terminal displays, retained recordings/recovery and deletion confirmation.

Existing live build5 screenshots were inspected: navy canvas, royal-blue hero, warm yellow primary action and white readable text already form a coherent sports interface. Keep that structure, semantic scalable typography, generous spacing and clear primary action. Complete the missing launcher icons and visible brand; avoid a gratuitous redesign. “Practice”, “Sessions”, “Set up” and other functional route titles stay descriptive. Native Liquid Glass remains on existing applicable controls/navigation; long content stays opaque, and the existing Reduce Transparency fallback is preserved. Empty states remain honest; no invented sessions, shot scores, players or social activity.

Data-backed capture/detail/sheet/transfer screens cannot be claimed visually proven by empty simulator data. Source review and deterministic model tests cover their unchanged logic; actual physical/data-backed UI observation remains a separate gap.

## Verification matrix defined before edits

- Use only `/Applications/Xcode.app/Contents/Developer`, verified Xcode27.0/27A266a, iOS/watchOS27 SDKs. Keep all build/result files outside the repo.
- Freeze a new source manifest including both PNGs and icon tool. Verify an incremental eight-file production/config boundary, unchanged protected bytes/settings and no remaining old brand in user-facing literals.
- Validate reproducible PNGs as opaque 1024×1024, both catalog references, actual compiled assets and both built products' display names/version/build/bundle identities. App icons must survive phone rounded-square and Watch circular masking.
- Build both Release simulator schemes and signed generic iOS device scheme; strictly verify phone and embedded Watch signatures separately. Do not install or update provisioning.
- Run full phone app-host/UI suites and full Watch app-host/UI suites serially on existing paired OS27 simulators: phone `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`, Watch `91757361-AEA2-41D8-9C4F-6DE5FF6365DA`. Use explicit nonparallel execution, timeouts enabled, default/maximum300 seconds. Preserve each failure and result; no automatic retries or relaxed assertions.
- Phone UI coverage retains standard navigation, largest-text portrait/landscape, all guides/shot/reference labels, Sessions empty state and launch variants; add visible Padel Master/absence-of-old-wordmark checks. Watch coverage retains every wizard, shot choice, consent reset, relaunch, background and retained-control assertion plus launch variants.
- Export real test screenshots. Root separately inspects actual light/dark/large-text/reduced-transparency appearance and restores any changed simulator accessibility setting. Do not use an unverified launch argument to claim accessibility behavior.
- Root verifies unchanged core and consolidates final evidence; independent reviewer challenges exact source. Local results do not prove exact-HEAD remote CI or physical sensors, permissions, continuity, transfer/export, battery or on-court usability. Physical last-known installed build remains4.

Acceptance requires correct visible branding and icons, preserved behavior/identifiers, no readability regression in inspected routes, all required automated checks reported honestly, and explicit remaining physical/release gates. No “ready for court” or quality-measurement claim follows this branding work.

## Approved accessibility refinement before correction

Actual run10 largest-text portrait screenshots `7FE26B17-4EE1-4A59-8DB5-47EBD03661F7.png` and `80ED24A3-9E90-42D1-A62F-B37D6C9AA84E.png` show “YOUR / TRAIN- / ING” and “YOUR / REFER- / ENCE”: decorative artwork and its Spacer compress the eyebrow. Root independently inspected these and approved a single phone `ContentView.swift` correction covering its hero and private `GuideHeading`.

At accessibility Dynamic Type sizes, hide only the decorative court/symbol and their Spacers. Preserve all semantic text, actions, identifiers, state and normal-size appearance. Acceptance: YOUR TRAINING and YOUR REFERENCE wrap using whole words at maximum text size; existing full phone navigation and largest-text tests pass, with manual inspection of their actual screenshots. No constant-mirroring test is needed.

Preserve the 60-entry `9112e8cf7be7d00dc3ba645e4828c3ef2925a8bee171ca9068eb663918bfb2d9` source/manifest in `author/12-before-accessibility-source-9112.tar.gz` and leave that repository manifest immutable. Write a new 60-entry accessibility manifest and update only the existing workflow reference. This remains within the same eight production/config files. Candidate version1.0/build6 stays unchanged because it has not been published or physically installed; hashes distinguish the intermediate and corrected source.

Rebuild phone Release and signed generic device products, separately verify both signatures, and run only the full relevant phone app-host/UI targets once with the same explicit300-second limits. Carry completed Watch UI/Release evidence only with proof that every Watch/core/design/project/asset/test input remains byte-identical. Run the still-missing Watch app-host target separately after verified unlock. Preserve run11's actual phone timeout and cancellation; do not report its overall invocation as passed.

## New owner UX direction — separate pending plan

The owner subsequently requested that detailed setup move primarily to iPhone because the Watch is too small. Root is planning a phone-led flow with brief Watch placement/orientation/fit confirmation and explicit Watch Start. No such flow, connectivity handoff or new authority is implemented in this branding increment. High-risk implementation waits for the owner's concrete plan approval. The currently tested six-step Watch wizard is an interim baseline, not the final accepted setup UX; future flow changes invalidate affected evidence.

### Interim verification refinement after owner clarification

The owner clarified that iPhone is the main terminal, Watch is the logger with brief statistics, and the intended final product identifies shot variety/contact quality automatically. Current manual shot intent is development reference collection only, not a trained algorithm or final end-user teaching workflow. The owner selected phone setup once per practice with brief Watch confirmation and explicit Start for each set. Root is resolving remaining architecture clarifications before high-risk code; this increment does not implement that flow.

After owner unlock confirmation and a fresh error-free native inventory, root authorized only the missing Watch app-host target and three phone UI cases on the unchanged corrected `1c7233` source: largest-text portrait, largest-text landscape and standard practice/contact navigation. All original assertions, bounded scrolling and explicit300-second limits remain. Do not repeat unrelated launch-performance/empty-state suites for the soon-to-change guide flow. These checks establish interim accessibility behavior only; the forthcoming phone-led implementation must receive its own full relevant phone/Watch regression and visual review. Capture the actual whole-word eyebrow results and release the pair for root's synthetic-data visual review afterward.
