# Theme A3 — readable deletion confirmation sheet

20 October 2026. Author: GPT-6 Astra, Extra High reasoning. **Proposal for director ratification and independent safety review. No A3 code authorized until ratified.**

## Evidence and baseline

Branch `feature/guided-padel-setup`, unchanged HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Preserve all unpublished work. Private evidence root is `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-TurquoiseTheme`.

A2 source19 manifest has 69 entries and SHA-256 `b565d803c0f61886d8221be596b77227a81f3803a4feb6573ef7c8730b53b384`. A2 phone Release17 passed. Focused UI20 passed full-warning/Cancel-retains/single-delete-to-empty-library assertions after the preserved UI18 XCTest query-length failure was corrected without weakening assertions. The native alert still fails contrast: settled `21-a2-alert-settled.png` and `21-a2-settled-alert-contrast.json` measure 3.31:1 for the warning, against 4.5:1 required. Actual dark OS, ordinary text, Reduce Transparency off and Increase Contrast off were observed. This proposal does not erase that failure.

## Bounded implementation

One production file: `PadelStrokeLab/RecordingDetailView.swift`, at most 180 added/removed lines relative to source19. Existing `PadelStrokeLabUITests/MotionStatisticsUITests.swift`, at most 120 added/removed lines for the focused regression. Shared theme tokens, core/model/repository, permissions, capture, transport, project configuration and every other source19 input remain byte-identical.

Replace only the failing native alert with a public SwiftUI sheet. Use an opaque shared canvas/surface, shared primary/secondary ink, visible semantic destructive and Cancel buttons, and a scrollable layout that keeps the full warning and both actions reachable at largest text in portrait and landscape. Preserve exact title “Delete this iPhone copy?”, warning “This removes this iPhone's raw recording and owner labels. The Watch original stays on your Watch. Exported or shared copies remain outside this deletion.”, action “Delete iPhone copy”, and “Cancel”. Add semantic accessibility identifiers for the confirmation container and controls; retain existing identifiers.

Keep the existing guarded `requestDeletion(recordingID)` and `confirmDeletion(recordingID)` model calls. The model removes the library row and closes selected detail before returning success; that row owns the navigation link. Therefore deletion must start only after the sheet finishes dismissing. On Confirm, synchronously admit one captured recording ID, set a local in-flight gate, disable both actions/interactive dismissal, and close the sheet. Its `onDismiss` consumes that confirmed intent exactly once and starts the existing guarded deletion. The confirmed path must not call `cancelDeletion()` first. Keep the admission gate closed against reopen/repeated taps until the result returns. Repeated dismissal callbacks must not replay deletion. On success, dismiss only the original recording detail; on failure retain the existing error with no pop or automatic retry. Cancel and ordinary swipe dismissal clear pending deletion and launch no delete. No sheet may remain presented when the model mutates the library.

No private appearance APIs, global native styling, fake warning actions/titles, custom model behavior, new fixture seams, data migration or unrelated fixes. A2 prompt/section changes remain intact.

## Acceptance and verification

Freeze the exact incremental diff and new 69-entry manifest. Build affected phone Release with Xcode 27; verify unchanged Watch identity/embedding. Run only the adapted focused isolated-fixture regression, retaining exact complete warning assertion and Cancel-retains proof, then one deliberate deletion of disposable fixture `A6201020-0007-4000-8000-000000000001` and empty-library return. Ratification authorizes that single test-only deletion and no other deletion. Include idle swipe-dismiss/reopen and rapid-repeat confirmation coverage, plus exact final navigation. Inspect the single-consumption gate and post-dismissal deletion ordering independently. Existing model evidence remains historical; do not invent a runtime failure-path result without a supported route or add a new fixture seam.

Personally inspect ordinary/largest text, portrait/landscape, actual light/dark OS with dark app, Reduce Transparency/Increase Contrast responses, whole warning and both actions. Measure actual normal text at least 4.5:1 and controls at least 3:1. Preserve A2 failures and all results. Restore simulator settings/orientation/preferences, normally launch tested Release products, and recheck the separate default synthetic recording's eight original files.

Update the focused evidence report and obtain independent read-only review of the exact final source/evidence before acceptance. No Git mutation, physical install, external sharing, release, icon B or participant implementation is authorized here. Icon B still requires explicit director handoff.
