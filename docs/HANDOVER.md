# Foundation handover

Updated 16 October 2026. This is a local preparation foundation, not the completed WP1 recording tester.

## Verified state

Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `chore/project-governance`; HEAD/base/live remote main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. Ahead/behind 0/0, no upstream, no PR, no new commit/tag/release. Existing uncommitted generated files and README work were preserved.

The six-file production foundation provides preliminary metadata/self-label values with a versioned bounded JSON codec, a phone preparation screen, Watch playing-arm setup/confirmation and shared-package integration. All app/test deployment targets are 27.0; original signing/team/bundle/companion settings remain intact. No recorder, durable recording format, contact scoring, transport or AI has been added.

The current authority is `PSL-SPEC-001 v1.1`, with the retained OS 27 amendment. The 507-paragraph snapshot and source revision are in `docs/product/`; the older PDF and dated authority/Gate Card are preserved. The owner-led normal-practice path, uncertainty and repeat-label checks supersede conflicting mandatory-coach/large-study assumptions.

## Evidence and limits

Exact source manifest: [261016_Foundation_Code_State.sha256](testing/261016_Foundation_Code_State.sha256), SHA-256 `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`.

[Local evidence](testing/261016_Foundation_Local_Evidence_v1.0.md) records all commands, destinations, logs and result bundles. Final result: shared-core 29-test suite and both Release simulator builds pass. The iPhone suite passes seven executions; the Watch scheme passes 12 executions across all four generated test targets. Zero failures/skips. No retry-on-failure was used. Generated app unit/UI templates offer only placeholder/launch smoke coverage; meaningful metadata validation is in PadelCore.

Artifacts: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/` contains `Logs/`, `Results/`, `Attachments/` and app builds. Shared-package scratch: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Core-Foundation/`. These outputs are outside source/Drive.

Physical iPhone 15 Pro / Watch Ultra 2 builds, signing/install, pairing, orientation, capabilities/rates, accessibility, battery, on-court recording and label quality remain unverified. CI and independent committed-HEAD review remain open. The active project was not relocated to Drive; a pre-edit archive is retained there. Source/report publication to GitHub is authorized; the publication record below will identify the committed baseline.

## Owners and next actions

The owner authorized saving the foundation to GitHub. GitHub is now the development source of truth; the local checkout remains the active Xcode workspace. Google Drive retains specifications and Word documents, and earlier source/evidence archives remain historical backups. See [ADR 002](adr/002-source-of-truth.md).

The coordinator will publish the existing foundation on `chore/project-governance` and open a draft pull request. A new independent reviewer must inspect committed HEAD without modifying files. CI and relevant physical checks remain open; merging and release are not authorized.

The next coding increment needs an approved minimal capture/data contract, including explicit recording state, resource ownership, observed timing/rates, bounded durable chunks, interruptions and honest saved-state semantics. Label timing, confidence and source evidence remain part of the future format. Do not broaden this foundation to satisfy the whole SoW.
