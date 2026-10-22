# Black, turquoise and white — presentation contract v1.0

20 October 2026, Asia/Dubai. Author: GPT-6 Astra, Extra High reasoning.

**Status: PLAN ONLY, pending director ratification before source, test, build or UI work.** The owner requests the supplied premium black/turquoise/white reference across every iPhone and Watch page, menu and submenu. This supersedes the earlier blue/yellow/white presentation direction. Keep native Liquid Glass, readable controls and the existing product behavior. The app should present its dark design even when the operating system uses light appearance.

## 1. Reference, authority and baseline

The supplied reference was visually inspected at `/var/folders/vq/wwwy3_716zg77wy7h21__4dw0000gn/T/codex-clipboard-97f7474a-a3d4-446b-9cc5-ecf853677553.png`, SHA-256 `0907e37da504dcd95e562c6b1675c76480d38c5bd875fc7e986aecfb00751bd8`. It shows near-black canvases, restrained charcoal cards, bright turquoise actions/selected accents/charts and white/gray text. Use that visual language, not its unrelated task/productivity content or invented dashboard values.

Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, with intentional unpublished changes and no upstream. The accepted baseline is [the final statistics 69-entry source manifest](../testing/261020_Motion_Statistics_A_Code_State.sha256), SHA-256 `cd0f9af6fd4d7bb3ea0873983c1f5d34441589edd9a8cc297cbf5ccb83b7ee9a`. All 69 entries were checked against disk without mismatch while authoring this contract.

The coordinator reports final statistics UI21 passed 15 executions/12 unique tests with zero failures, reviewed seven actual visual captures, verified exact restoration of eight synthetic fixture files, and confirmed the tested standard Release15 executable/default launch. The statistics author explicitly released the simulator pair and has no remaining source jobs. These are the preceding package's results, not evidence for the new colors. Theme implementation still waits for this contract's ratification and explicit implementation release.

Participant A remains held while this owner-prioritized presentation package proceeds. Preserve every reviewed participant artifact unchanged, including v1.2 SHA-256 `7e6c11587182395a654d0294a1932082242534f2490bfa74275930bc4b4572a1` and v1.3 amendment SHA-256 `2fd597c16f7207410e9cc035c5a6840384f9864e74aa46c657ce2bbcdeb76f44`.

Before implementation, re-read repository authority/governance and the current gate; reconcile branch/HEAD, worktree ownership, remote/PR state and this exact baseline. Verify Xcode 27 and both OS 27 SDKs. Every Swift/Xcode invocation must use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; generated outputs remain outside source/synced folders.

## 2. Bounded styling package

Risk Level 2 presentation work. At most **eight production/configuration files and 2,500 changed text lines**:

| Allowed file | Permitted change |
| --- | --- |
| `Packages/PadelDesign/Sources/PadelDesign/PracticeTheme.swift` | Semantic palette, neutral hero/cards, action-label contrast, native-glass/Reduce Transparency treatment and decorative court accent. |
| `PadelStrokeLab/ContentView.swift` | Replace direct blue/yellow named-token use on home, practice guide, reference guide and callout; preserve layout behavior, copy and navigation. |
| `PadelStrokeLab Watch App/ContentView.swift` | Black canvas, charcoal rows, semantic accents, contrasting action labels and native navigation-control treatment. |
| `PadelStrokeLab Watch App/WatchPreparationView.swift` | Apply matching colors to all six existing steps, selection, warnings, toggle and actions; preserve all preparation behavior. |
| `PadelStrokeLab/PadelStrokeLabApp.swift` | Set app-default dark appearance and required presentation inheritance only. |
| `PadelStrokeLab Watch App/PadelStrokeLabApp.swift` | Set app-default dark appearance and required presentation inheritance only. |
| `PadelStrokeLab/Assets.xcassets/AccentColor.colorset/Contents.json` | Explicit sRGB turquoise accent for native accent consumers. |
| `PadelStrokeLab Watch App/Assets.xcassets/AccentColor.colorset/Contents.json` | Matching explicit sRGB turquoise accent; scoped native-control overrides remain allowed above. |

`RecordingLibraryView.swift`, `RecordingDetailView.swift` and `RecordingStatisticsView.swift` already use the shared semantic theme and inherited native appearance. They are **protected, not additional allowed edits**. Retain the meaningful `canvas`, `surface`, `ink`, `secondaryInk`, `accent` and `hero` interfaces so they inherit the new presentation. Remove obsolete public `navy`, `royal` and `yellow` names and their callers within the allowed files; do not retain misleading color aliases. Replace `watchSurface` with the shared semantic surface where practical.

Semantic theme functions may keep their existing `ColorScheme` parameter to avoid unrelated call-site edits, but their presentation contract is now the same approved dark palette. The app-root `.preferredColorScheme(.dark)` must also establish native control/sheet appearance. The installed watchOS 27 SDK exposes this public SwiftUI modifier; actual navigation and modal inheritance still require verification.

If an inherited detail/editor/native menu cannot meet the contract through these eight files, report the exact failing surface and propose a separately scoped amendment or split **before editing a ninth file**. Do not conceal an inaccessible control or carry a blue remnant to satisfy the file cap.

Tests may make focused updates only in the existing phone main UI test file, `PadelStrokeLabUITests/MotionStatisticsUITests.swift`, and the existing Watch UI test file: preserve behavioral assertions, use truthful new screenshot/test labels and verify the requested appearance under actual OS settings. No new production fixture, capability bypass or alternate app state is included.

## 3. Palette and measured solid-color contrast

The following sRGB values are a concrete implementation target informed by the reference. They are not claimed to be exact sampled reference pixels.

| Semantic role | sRGB | Use |
| --- | --- | --- |
| Canvas | `#050809` | Near-black page and Watch navigation background. |
| Surface | `#131B1D` | Opaque charcoal cards/list rows. |
| Elevated surface | `#1B272A` | Restrained raised/hero endpoint; no blue gradient. |
| Primary ink | `#F5FAFA` | Main text and ordinary foreground symbols. |
| Secondary ink | `#AEBFC3` | Supporting text, metadata and captions. |
| Accent | `#10D7CE` | Turquoise filled primary actions, selected markers, chart points and text accents on dark backgrounds. |
| Pressed accent target | `#0DB9B1` | Darker turquoise if a custom pressed fill is needed; native pressed rendering remains subject to inspection. |
| On-accent ink | `#041313` | Dark text/symbols on bright turquoise. |
| Native navigation fill | `#006F6A` | Dark turquoise for native controls whose glyph remains white, particularly Watch close controls. Not a general small-text color. |
| Control outline | `#68858A` | A contrasting edge where an enabled control depends on its boundary for identification. |
| Decorative separator | `#2C3A3D` | Subtle nonessential card/divider decoration only. |

Ratios below were calculated using the WCAG sRGB relative-luminance formula, `(Llighter + 0.05) / (Ldarker + 0.05)`, on the opaque target values:

| Foreground / background | Contrast |
| --- | --- |
| Primary ink / canvas | 19.08:1 |
| Primary ink / surface | 16.58:1 |
| Primary ink / elevated surface | 14.55:1 |
| Secondary ink / surface | 9.18:1 |
| Secondary ink / elevated surface | 8.06:1 |
| Accent / canvas | 11.13:1 |
| Accent / surface | 9.68:1 |
| On-accent ink / accent | 10.50:1 |
| On-accent ink / pressed accent | 7.76:1 |
| Pure white / bright accent | **1.81:1 — prohibited for readable action labels** |
| Pure white / native navigation fill | 6.03:1 |
| Native navigation fill / canvas | 3.33:1 — suitable only for the intended non-text control boundary, not ordinary small text |
| Control outline / elevated surface | 3.88:1 |
| Decorative separator / surface | 1.48:1 — not an essential control boundary |

Require at least 4.5:1 for normal text and 3:1 for large text and essential non-text controls. Solid-token calculations do not prove rendered Liquid Glass, opacity, disabled states, native symbols or chart axes. Inspect and measure representative actual captures, including the darker endpoint beneath secondary text. Do not claim every rendered state passes from the table alone.

## 4. Presentation rules

- Keep the canvas black and content cards opaque charcoal, with white/gray text and restrained turquoise emphasis. Preserve the existing spatial hierarchy, typography, semantic Dynamic Type and decorative-art hiding at accessibility sizes. Do not turn every card into a turquoise panel.
- Bright turquoise filled actions require dark labels/symbols in both normal glass and opaque Reduce Transparency alternatives. Explicitly verify NavigationLink labels, Watch action buttons and disabled/pressed states; an inherited white foreground must not override on-accent ink.
- Native Watch close/back/control glyphs must remain readable. Use the darker navigation-fill token where a native white glyph cannot receive an appropriate dark foreground. Scope overrides carefully: dark navigation fill must not become low-contrast small body/link text. Inspect the native shot-picker close control, Back, Cancel and selected options.
- Native Liquid Glass remains for applicable navigation and actions; no simulated blur or translucent long-form content. Keep the existing Reduce Transparency solid primary-action fallback and verify the system's handling of other native glass controls, including export and toolbar actions.
- Every app-owned screen and presented menu/sheet must remain dark when the OS is light or dark. Do not change the user's global appearance preference to achieve this. Native share/confirmation surfaces must inherit a legible compatible presentation through public APIs; third-party destination apps are outside app control.
- Preserve semantic destructive/error treatments and text, including existing native red destructive actions and validation errors. Red is a functional signal, not the superseded brand accent. Selection, warnings and availability must remain understandable from text, shape or state—not color alone.
- No blue/yellow brand color remains in app-owned page backgrounds, heroes, primary controls, selection markers, charts or native accent assets. Static source inspection and actual screenshots are both required; one does not replace the other.
- Launcher/App Store icon PNGs and icon catalog entries are explicitly outside these eight files. They remain a separately bounded later palette-asset step; this package cannot claim icon recoloring. No raster image is edited here.

## 5. Screen, menu and state inventory

| Surface | Required coverage |
| --- | --- |
| iPhone Practice home | Wordmark, hero, Let’s Play glass action, Sessions link, reference link, explanatory note and Watch reminder. |
| Practice guide | Header, all six current instructions, intended-shot list, uncertainty card, first-attempt text and native back navigation. |
| Contact reference | Header, five categories/icons, turquoise callout with dark text, explanatory footer and back navigation. |
| Sessions | Loading, empty, error, populated rows, transfer status and Refresh toolbar; all inherit the shared theme. |
| Recording detail | Summary, interrupted/warning states, retained coverage, capture metadata and selectable identifiers. |
| Motion statistics | Wrist acceleration/rotation metrics, turquoise point traces, readable axes/captions, raw-acceleration DisclosureGroup collapsed/expanded, unavailable and interrupted cases. Values and calculations are unchanged. |
| Add/edit attempt sheet | Form sections, Contact/Confidence/Evidence pickers and their menus/subpages, note/time fields and keyboard, validation error, Save/Cancel/close presentation. |
| Recording data actions | Prepare export glass action, progress, ShareLink/share sheet, delete confirmation and Cancel; use synthetic isolated data for inspection. |
| Watch landing | Let’s Play, training card, current capture-state text, limits/notices and navigation title/background. |
| Watch preparation steps 1–3 | Racket/usual-hand selections, placement, actual wrist/crown and mismatch explanation, Refresh, Back/Cancel and action enabled/disabled appearance. |
| Watch preparation steps 4–6 | Fit, native shot picker and every selectable label, selected checkmarks, Other explanation, review, final-confirmation toggle, blocker and Start appearance. |
| Watch native picker/navigation | Close glyph/fill contrast, Back/Cancel, focus/selection, scrolling and long shot names. Do not infer these from custom-button screenshots. |
| Watch capture states | Starting, recording, pausing/paused, resuming, stopping and terminal saved/interrupted/failed content; Pause/Resume/Stop/new-set controls. Styling changes cannot alter state availability or ordering. |
| Watch retained/recovery | Recovery notice/dismiss, empty/inspection status, retained rows, transfer/retry, refresh, deletion status and native delete confirmation/Cancel. |

Use existing authorized synthetic fixtures for populated phone detail/statistics/editor routes; retain their visible synthetic designation. Do not seed or alter personal libraries, perform a real transfer or send an export. Inspect confirmation dialogs and cancel them. Opening a share sheet is not permission to share.

Some live Watch capture states may remain unreachable in the simulator with existing approved fixtures. For those, explicitly record source/token inspection and applicable existing model tests, with visual coverage still unobserved. Do not bypass capture guards, invent successful hardware operation or add a production fixture to fill the gap. Report any such limitation before claiming complete visual coverage.

## 6. Accessibility and actual appearance checks

- Inspect phone portrait and landscape at ordinary and maximum accessibility Dynamic Type. Preserve whole-word TRAINING/REFERENCE headings, all statistics units/values, scrollable long text and reachable controls. Decorative artwork must not compress essential content.
- Inspect Watch ordinary and largest supported text, long picker labels, final confirmation and native close control. Keep practical native touch targets (iPhone approximately 44 points and Watch approximately 44 points where applicable); never shrink fonts or hit areas to make a screenshot fit.
- Verify labels, selection values, disabled state, VoiceOver reading order and headings remain intact. Preserve every existing accessibility identifier and functional hint; there is no screen-flow/copy redesign.
- Enable Reduce Transparency through a verified simulator/system setting, observe the actual opaque fallback, then restore the prior setting. Inspect Increase Contrast for text, controls and card/outline distinction; do not rely on an unverified launch argument or an assumed material response.
- Set the actual iPhone OS appearance to light, assert that setting in the test, and inspect the app's dark pixels; repeat with actual OS dark appearance. Record OS appearance separately from app appearance and restore it afterward. A screenshot from the new app must never be called “light app mode” merely because the OS was light.
- Native toolbars, pickers, sheets, confirmation dialogs and Watch close controls need their own captures where their foreground/background differs from the parent page. Check bright-turquoise/white failures explicitly, including pressed and selected native states.

## 7. Verification and evidence invalidation

After ratification and explicit implementation release:

1. Preserve the accepted source69 baseline and an incremental before-state snapshot. Verify that only the eight allowed production/configuration files and declared UI-test/documentation files change. Inspect the whole app/theme usage for remaining blue/yellow literals or obsolete tokens; validate both AccentColor catalogs.
2. Keep all capture, preparation, storage, statistics, transfer, labeling, permission and deletion logic byte-identical. No core/model/app-host-test changes are allowed. Retain prior logic results only with exact protected-input evidence; theme changes do not retroactively invalidate unchanged reducer/model results, but they invalidate affected app-build and visual presentation evidence.
3. Build both iPhone and Watch OS 27 Release products. Do not change build number, signing, bundle IDs, project settings or provisioning. No physical installation or release is included.
4. Run the affected existing phone and Watch UI checks serially on the explicitly released OS 27 simulator pair, retaining navigation, preparation/selection/confirmation assertions and statistics behavior. Reuse the existing UI/accessibility checks and actual synthetic fixtures; do not add behavioral tests that mirror color constants. Preserve the accepted full statistics UI result (15 executions, zero failures), core 138 and unchanged app-host results as baseline evidence for their exact inputs. Do not rerun broad core/app-host suites for palette-only changes; run a relevant additional regression only if a source change, observed failure or unresolved integration concern justifies it. Preserve each failed attempt; no automatic retries or relaxed tests.
5. Update misleading appearance-specific test/screenshot labels for the intentional dark-app behavior while retaining genuine OS-appearance selection/assertion/restoration. Add only meaningful appearance/navigation coverage; no tests that merely mirror palette constants. Existing synthetic fixture isolation, exact-control queries and bounded scrolling stay intact.
6. Capture and personally inspect the inventory above in the requested palette, including largest-text portrait/landscape, native menus and verified Reduce Transparency. Compute representative rendered foreground/background contrasts where compositing/native styles differ from the opaque table. Record unobserved states explicitly.
7. Restore every changed simulator appearance/accessibility/orientation setting and any authorized synthetic fixture state exactly; verify a normal non-fixture Release launch. Do not alter another task's data or infer restoration from a successful exit code.
8. Freeze a new source manifest and write focused evidence with exact source identities, changed files/line counts, commands/results, screenshots, palette calculations and remaining gaps. Obtain an independent read-only exact-source review before acceptance and the subsequent participant baseline handoff.

The source69 statistics logic and earlier functional results remain historical evidence for their exact inputs. Their blue/yellow screenshots, and earlier light/dark palette captures, cannot prove this theme. Fresh images must show the actual black/turquoise/white application; screenshot filenames or OS settings alone are insufficient.

Formal committed-HEAD review, current hosted CI, physical usability/sensor evidence, user-approved Git publication/merge and any icon/release package remain distinct gates. No “ready for court,” measurement or guest-acquisition claim follows this presentation work.

## 8. Non-goals and next gate

No phone-led setup implementation, participant types, consent policy, Health/workout changes, capture/state transitions, sensor expansion, statistics algorithms, transport, data/schema changes, permissions, signing, dependency or storage changes. No new pages, invented metrics, chart data, social features or product claims. Existing interim six-step Watch preparation remains functionally intact.

No commit, push, PR, merge, branch deletion, device installation, TestFlight or App Store action is authorized. This is theme Package A. The separate [Package B icon asset contract](261020_Black_Turquoise_White_Icon_Assets_Contract_v1.0.md) defines palette-only editing of the existing native icon generator and deterministic rendering of its two existing PNG outputs after A's source is accepted and frozen. No raster pixel editing or image generation service is included.

**One next action:** director ratifies this exact eight-file presentation contract and explicitly releases implementation against source69. Until then, make no source/test/build/UI changes. After accepted theme evidence and review, the coordinator hands the new frozen baseline to participant A.
