# Blue, yellow and white UI contract

17 October 2026. Owner explicitly requests a modern, professional premium interface, blue/yellow/white palette, consistent pages and subpages, and Apple Liquid Glass where appropriate. Physical installation remains on hold until simulator UI review.

## Bounded scope before implementation

Risk Level 2: presentation, native navigation and existing Watch setup state. Continue on the unmerged bootstrap branch `chore/project-governance`, base `main` f21bfab, initial reviewed preparation HEAD cfea609203a68f3195cc5f864060bc356403a605. Do not change metadata, recording, permissions, entitlements, signing, deployment or CI behavior.

Create a small dependency-free local SwiftUI design package reused by both applications; keep PadelCore independent of UI. Maximum eight production files and 2,500 changed lines. Expected production scope: new package manifest and theme/components source, Xcode local-package integration, both ContentView files (five files). Native platform controls differ appropriately; shared palette, spacing, type hierarchy and content surfaces remain consistent.

Inventory: iPhone practice home, forehand practice guide, contact-reference guide; Watch preparation and native arm picker. Existing product has preparation only: new guides are explanatory navigation, not capture, label entry or training measurements. Do not invent scores, histories, players, sessions, achievements or enabled recording controls.

## Design and Apple material use

Use a deep blue/royal blue brand, warm yellow accent and clear white/pale-blue content surfaces. Yellow uses dark readable ink. Use semantic scalable system typography, generous space and restrained court/sport artwork made in SwiftUI if useful. Premium quality comes from hierarchy, alignment, readability and purposeful interaction.

Liquid Glass belongs on controls/navigation above content, not every content card. Use native glass button/navigation styles supported by the installed SDK. Keep long-form cards opaque and legible. Preserve native back navigation, scrolling, accessible control labels, touch targets, Dynamic Type, light/dark adaptation and reduced-transparency accessibility. Watch is compact and glanceable; native picker and real confirmation remain functional.

Apple references verified before coding:
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views

## Verification contract

Before screenshots/claims: compile both applications using Xcode27 and iOS/watchOS27; do not use26.5. Re-run 29 PadelCore tests for regression, both Release builds and affected app UI suites. Do not add tests that merely repeat color/layout constants. Existing launch tests alone do not prove navigation or styling.

Inspect actual simulator captures for each page and Watch picker/confirmed state where tooling permits; exercise navigation/back and Watch arm-change confirmation reset through real UI automation or report any unavailable interaction honestly. Check standard and large text plus reduced-transparency appearance, readable yellow/white/blue contrast and no inaccessible/clipped actions. Do not force a light theme to hide dark-mode problems.

Update the source fingerprint and evidence for the changed exact source; old source fingerprints/screenshot evidence are historical. Existing hosted CI failure is a Watch runtime-profile environment blocker, not passed CI. UI changes invalidate affected prior build/test/review results. Preserve all failed attempts, no automatic retries.

Acceptance: every implemented screen uses shared palette/hierarchy; all enabled actions work; no pretend recording; builds and relevant tests pass or failures remain visible; user receives actual simulator images and, when available after Xcode downloads finish, a live Simulator window. No physical installation, merge or release in this increment.

Support scope clarification: the existing CI workflow may update its source-manifest path only to identify this new UI state. This is required evidence maintenance, not a CI execution or hosted-runtime remediation change. Existing phone/Watch UI test files may replace empty examples with meaningful navigation/confirmation regression flows and screenshot attachments.

### Regression clarification before test changes

Retain failed Watch UI attempt01 and regression02. Native Watch picker leaves an already selected value open; regression must choose a different arm from the persisted initial value, then assert each real state transition. Use short gestures inside the content region rather than edge swipes that can invoke system UI. Phone checks must establish and restore orientation, explicitly cover largest-text portrait and landscape, and scroll until an action center is visible rather than trusting `isHittable` for an offscreen descendant. These changes preserve all behavior assertions; failures remain blockers until understood.

Regression03 showed the native picker does not expose its current selection in the queried value. Before the next implementation edit, define an explicit accessible selection value on the existing picker and assert it in the UI test. This is presentation/accessibility metadata only; AppStorage keys and state semantics remain unchanged.
