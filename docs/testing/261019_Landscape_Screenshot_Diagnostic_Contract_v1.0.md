# Landscape screenshot diagnostic contract — v1.0

19 October2026. Defined before fixture edits. Branch `feature/watch-recording-storage`, committed baseline8075991; source frozen by55-file deterministic-lease manifest6b4b2c82. All local automation passed:108 core,23 Watch/8 phone app-host,8 Watch/9 phone UI executions; both Release builds and signed device build4/signatures. No installation/publication of this increment occurred.

## Observed evidence and review

Astra Extra High independently inspected original PNG pixels/metadata from `26-phone-all-ui.xcresult`, exported in private `26-phone-attachments/`. All four XL landscape guide/home captures and both ordinary-text landscape launch captures have2556×1178 raster, but nonblack pixels only at x0…1178,y0…1177;1377 remaining columns are zero RGB. Guide captures carry EXIF orientation8 and opposite-landscape launch captures orientation6. Portrait reference is1178×2556/orientation1. Removing orientation metadata leaves identical IDAT pixels and the same padding/cropping. This is not simply image resizing. Both collectors currently use `app.screenshot()`.

Repeated short-edge square content plus padded excess across pages/type sizes strongly supports application-frame cropping before orientation. Actual screen rendering remains unobserved; a production layout change would be speculative. Passing accessibility/navigation assertions alone do not close the visual gate. Preserve every original PNG and test result.

## Bounded allowed change

Astra High may modify only `PadelStrokeLabUITests/PadelStrokeLabUITests.swift` and `PadelStrokeLabUITests/PadelStrokeLabUITestsLaunchTests.swift`. Keep existing app screenshots as labelled original evidence; add paired `XCUIScreen.main.screenshot()` attachments and diagnostic app/window frames plus device orientation and each captured image's size/scale/orientation at each existing capture point. Use safe multi-window enumeration; do not introduce ambiguous single-window queries. No new dependency, application/production/configuration change, test navigation change, sleep, retry, disabled test, assertion relaxation or simulator reset. Existing screenshot names may remain; new attachments must be distinguished as full screen/geometry.

Parent alone updates the workflow's source-manifest reference and creates a new55-file manifest, retaining all previous manifests. All production, core, Watch tests and build configurations must retain identical per-file hashes. Their passing evidence carries only through that identity; current instrumented phone UI requires new evidence.

## Diagnostic and acceptance sequence

1. Freeze after fixture edits. Run one unchanged-assertion focused `testLargestTextLandscapeGuides` with300-second per-test bound, scoped idle/display sleep assertion and confirmed Mac-open/unlocked environment.
2. Inspect paired original app and full-screen images plus frame/orientation metadata. If full screen is sound and only app crop is defective, record a screenshot-collector artifact, retaining app captures as invalid visual proof. If the full screen also clips, stop and define a bounded Astra-reviewed actual-layout investigation before any production fix.
3. If the screenshot artifact is established, run the complete phone UI target once at the final source and inspect exported full-screen portrait/landscape/launch captures. All original assertions remain. No other passing suites/builds repeat without a changed file or unresolved concern.
4. Only after visual evidence is resolved, finalize docs, commit/push under the approved existing draft-PR cycle, obtain exact-HEAD CI and new independent committed-source Astra review. Physical recording/transfer/export remain unverified. No merge/release approval exists.
