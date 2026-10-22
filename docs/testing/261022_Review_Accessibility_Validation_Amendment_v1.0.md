# Review accessibility validation amendment v1.0

## Disposition — replacement method not accepted

### Current verification method (Run24; results pending)

All five original native categories run on the canonical initial detail viewport, before manual scrolling. Every original subsequent reachability/width/enabled/nonempty assertion remains; actual rendered element/viewport captures are additionally retained at each checkpoint. Standard-size native contrast runs at the same canonical initial state, with export-control visibility and render capture afterwards. This applies the independent reviewer's earlier test-sequencing recommendation; it is not the abandoned category split below.

The independent control establishes why arbitrary post-scroll native crops cannot be treated as color measurements: Control20's long white-on-black scroll content passes from its initial position, whereas Control23 fails after bottom anchoring on ordinary “Trailing signal 3” at y0.3, behind the navigation/status region. The app's Run21 similarly reports the Export label at y12811.3 although the control is visible. Retain these failures explicitly. Scrolled controls receive their original geometry assertions plus rendered-color review; do not describe the native initial-viewport audit as exhaustive native coverage of every offscreen paragraph.

The shipping view retains native metadata selection, restores eager layout, uses the existing solid dark summary surface, subheadline intended-shot value and the existing primary action style for Export. No recording/Health/data logic changes. Release22 passed; Build24 passed on unchanged shipping-view SHA `dfb32f926ea751f4c407365b10e4e3be1070eb53009a6b1ac7c55c077181ec9c`. Run24 must pass and the final independent reviewer must assess this complete evidence before the local UI gate can close.

The replacement contract below did not clear: Run13's standard-size native contrast tests also failed. It is retained as investigation history and is **not** the final acceptance method. A separate minimal SwiftUI control reproduced the native failure with a multiline footnote on a rounded dark gradient card (Control15 and Control16), then passed when only that card's background changed to solid dark (Control17). The app's review summary now uses the existing solid theme surface; its original five-category largest-text audits are restored without per-issue exemptions. A clipped intended-shot value is being corrected with the semantic subheadline style. Final verification and independent review are pending. No native-audit failure has been relabelled as a pass.

22 October 2026. Director ratification for the bounded results-screen correction on `feature/guided-padel-setup`, base HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Local and unpublished. Verification is pending; this is not physical-readiness or merge approval.

## Reason and retained failures

The native largest-text contrast audit repeatedly failed on different ordinary and offscreen SwiftUI elements. Toolbar opacity, selectable-text representation, replacement Copy controls and scroll padding did not resolve it; those experimental production changes were reverted. Run12 also failed from the fresh initial viewport on the fully visible white text “Verified receipt on this iPhone”. All failed runs remain retained in the local `PhysicalReadiness1` evidence directory.

Independent rendered-image inspection of Run12's exact portrait element crop (`/tmp/ContrastFix-12-both-all/38610533-10D2-4A45-AC56-CFAAE926A3E8.png`) found 59,791 white glyph pixels and substantial actual hero-background pixels at RGB(22,32,34). Their WCAG relative-luminance contrast is 16.616:1, exceeding 4.5:1. This contradicts a low-contrast interpretation for that visible example. It does not establish that every app state has passed contrast verification or that the native audit has passed.

## Replacement evidence contract

The separate read-only reviewer judged the following split defensible only when all replacement evidence is collected. Root ratifies its implementation as a test-method correction, with no relaxation of the product's readability requirement:

1. Native contrast audits must pass at standard text size on the same frozen source and synthetic fixture, in portrait and landscape. A standard-size result alone is insufficient.
2. Native sufficient-element-description, hit-region, text-clipping and trait audits must pass at accessibility XXXL in both orientations. Preserve all existing reachability, width, nonempty-label and enabled-control assertions and the 30-attempt navigation bound.
3. Retain largest-text screenshots at the initial screen and existing navigation checkpoints. Quantitatively verify actual rendered foreground/background roles, including hero, card, secondary text, prominent action, glass export control and navigation. Use a conservative 4.5:1 requirement for sampled text roles; source tokens alone cannot certify translucent backgrounds.
4. Keep original native largest-text contrast failures explicitly recorded as a simulator-audit limitation. Do not report them as passes or ignore individual unknown issues. The final independent review must assess the replacement evidence before this local UI gate can close.

## Scope and completion

Only `PadelStrokeLabUITests/OwnerPracticeReviewUITests.swift` changes for the split and retained captures. The proven bounded-drag correction remains. No sensor, health, persistence, transfer, export, deletion or recording behavior changes are authorized here. Existing reviewed layout changes are assessed separately. No new product feature or remote Git action is authorized.

Completion requires the four actual test results, frozen source hashes, rendered-color measurements with image/region identity, independent review and an updated current checkpoint. Failed or unavailable replacement evidence leaves this gate open. Physical sensor/transfer/background verification remains separate.
