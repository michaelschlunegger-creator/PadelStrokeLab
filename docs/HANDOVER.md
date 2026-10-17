# Foundation handover

Updated 16 October 2026. This is a local preparation foundation, not the completed WP1 recording tester.

## Verified state

Repository: `michaelschlunegger-creator/PadelStrokeLab`; active local checkout: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`. Branch: `chore/project-governance`, tracking `origin/chore/project-governance`. Foundation implementation commit: `7ae8a9855a52251b588e7cc4cb7ab2aa1fd7ebd0`, verified present on the remote branch. Base and unchanged live remote `main`: `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. [Draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1) is open against `main`. Initial publication was verified with a clean working tree and matching local/remote branch. Subsequent handover updates are documentation-only; use the PR head for the latest documentation identity. No merge, tag or release occurred.

The six-file production foundation provides preliminary metadata/self-label values with a versioned bounded JSON codec, a phone preparation screen, Watch playing-arm setup/confirmation and shared-package integration. All app/test deployment targets are 27.0; original signing/team/bundle/companion settings remain intact. No recorder, durable recording format, contact scoring, transport or AI has been added.

The current authority is `PSL-SPEC-001 v1.1`, with the retained OS 27 amendment. The 507-paragraph snapshot and source revision are in `docs/product/`; the older PDF and dated authority/Gate Card are preserved. The owner-led normal-practice path, uncertainty and repeat-label checks supersede conflicting mandatory-coach/large-study assumptions.

## Evidence and limits

Exact source manifest: [261016_Foundation_Code_State.sha256](testing/261016_Foundation_Code_State.sha256), SHA-256 `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`.

[Local evidence](testing/261016_Foundation_Local_Evidence_v1.0.md) records all commands, destinations, logs and result bundles. Final result: shared-core 29-test suite and both Release simulator builds pass. The iPhone suite passes seven executions; the Watch scheme passes 12 executions across all four generated test targets. Zero failures/skips. No retry-on-failure was used. Generated app unit/UI templates offer only placeholder/launch smoke coverage; meaningful metadata validation is in PadelCore.

Artifacts: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Foundation/` contains `Logs/`, `Results/`, `Attachments/` and app builds. Shared-package scratch: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Core-Foundation/`. These outputs are outside source/Drive.

Physical iPhone 15 Pro / Watch Ultra 2 builds, signing/install, pairing, orientation, capabilities/rates, accessibility, battery, on-court recording and label quality remain unverified. CI and independent committed-HEAD review remain open. The active project was not relocated to Drive; a pre-edit archive is retained there. GitHub is now the source of truth for code and development evidence summaries.

## Owners and next actions

The owner authorized saving the foundation to GitHub. GitHub is now the development source of truth; the local checkout remains the active Xcode workspace. Google Drive retains specifications and Word documents, and earlier source/evidence archives remain historical backups. See [ADR 002](adr/002-source-of-truth.md).

The coordinator published the foundation on `chore/project-governance` and opened draft PR #1. A new independent reviewer must inspect committed HEAD without modifying files. CI and relevant physical checks remain open; merging and release are not authorized.

The next coding increment needs an approved minimal capture/data contract, including explicit recording state, resource ownership, observed timing/rates, bounded durable chunks, interruptions and honest saved-state semantics. Label timing, confidence and source evidence remain part of the future format. Do not broaden this foundation to satisfy the whole SoW.

## Publication evidence

[GitHub publication record](testing/261016_GitHub_Publication_v1.0.md) links the implementation commit to the source fingerprint and local test results. CI is not configured; this PR remains draft. The next required action is independent review of the final committed branch HEAD.

## Physical-test preparation — 17 October 2026

The owner requested readiness for physical testing using Astra High. This increment adds the bounded [runbook](testing/261017_Physical_Foundation_Runbook_v1.0.md) and a hosted GitHub workflow; application/test/configuration files in the existing source manifest remain unchanged.

Preflight observed Xcode 27.0 (27A266a), iPhone 15 Pro with iOS 27.2 (24B5099f), and Apple Watch Ultra 2 with watchOS 27.0 (24R364), both available to Xcode over the network. Mac trust status does not independently establish the phone/Watch companion pairing. Both generic physical Debug builds passed, signature verification passed, and existing provisioning profiles include the respective observed hardware. These checks do not establish physical installation/launch. Full signed-build logs and result bundles are retained locally under `~/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Physical-Foundation/` and contain sensitive signing/device information excluded from GitHub.

Next: obtain clean hosted CI and refreshed review for the new committed HEAD, then guide the owner through one device action at a time. No recording, scoring or on-court feasibility claim is introduced. No merge/release is authorized.
