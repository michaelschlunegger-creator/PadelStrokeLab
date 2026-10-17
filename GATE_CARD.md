# Active Gate Card

Updated 16 October 2026, Asia/Dubai. Prior bootstrap gate is preserved [unchanged as history](docs/history/260824_Governance_Gate_Card_v1.0.md).

## Package and authority

Task: first preparation foundation for WP1, following owner authorization to start from `PSL-SPEC-001 v1.1`. The owner requested Astra with Extra High reasoning for foundational coding; implementation review is separate from the future independent committed-HEAD review.

Risk: Level 3 for preliminary metadata integrity/serialization, bounded to one domain. No sensor/workout, transport, persistence of recordings, concurrent capture, scoring or AI implementation.

Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`. Branch: `chore/project-governance`, upstream `origin/chore/project-governance`. Implementation commit: `7ae8a9855a52251b588e7cc4cb7ab2aa1fd7ebd0`, verified pushed. Base and unchanged live remote main: `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. [Draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1) is open. GitHub now stores the code and development record; see [ADR 002](docs/adr/002-source-of-truth.md).

The generated project/governance files and prior README work were preserved in the initial foundation commit. Source was published after the owner directed using GitHub. No merge or release occurred. Exact tested source is identified by [the source manifest](docs/testing/261016_Foundation_Code_State.sha256), SHA-256 `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`. Publication/handover changes after implementation are documentation-only.

Current product authority and immutable snapshot: [Product Authority](docs/PRODUCT_AUTHORITY.md). v1.1 supersedes conflicting older coach/study assumptions. The historical v2.0 PDF remains unchanged at `939c5858420124a4fe3753e3812c7ad594f3a2755c7225b7f2ebe6c13238af25`.

Xcode 27.0 (27A266a), Swift 6.4 and both OS 27 SDKs are verified. Every command explicitly uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Global selection remains CommandLineTools; it was not changed. All six app/test targets now require 27.0.

The owner confirms iPhone 15 Pro and Watch Ultra 2 on the latest OS. Exact physical builds, install, pairing and sensors remain unverified. Source remains in Documents/GitHub; no relocation to Drive occurred. The pre-edit Drive archive SHA-256 is `c24ef93b51fed90b40d66f4b1dacd1e47f9d2f95cdc0800916866907d76e375a`.

## Scope, invariants and failures

Allowed production files (six, 308 changed lines against pre-foundation backup):

- `Packages/PadelCore/Package.swift`
- `Packages/PadelCore/Sources/PadelCore/PracticeModels.swift`
- `Packages/PadelCore/Sources/PadelCore/PracticeArchive.swift`
- `PadelStrokeLab/ContentView.swift`
- `PadelStrokeLab Watch App/ContentView.swift`
- `PadelStrokeLab.xcodeproj/project.pbxproj`

Tests and authority/architecture/plan/evidence/handover documentation support only this package. Historical files remain immutable copies. Signing identities, companion relationship and six-target structure are preserved; there are no external dependencies.

Self labels remain self assessments. Invalid ordinals/revisions, conflicting identities, unsupported meanings/schemas, malformed notes/dates and oversized metadata must be rejected. Equivalent histories encode deterministically. Metadata must never imply a recording or measurement exists. Playing-arm confirmation clears when the arm changes. Raw streams, durable storage, label timing/confidence and full S1-05 are future work.

Forbidden: sensors/workouts, recording controls, transfer/export of recordings, cloud/community/AI, new entitlements or permissions, paid involvement, unrelated edits and Git publication without explicit approval.

Failure paths include silent metadata coercion, lost provenance, duplicate attempt identities, UI implying recording, wrong SDK/deployment targets, treating placeholder tests as full coverage, overwriting history and applying evidence to changed code.

## Gate status

- **G0 VERIFIED:** repository, base, pushed implementation commit, matching upstream, draft PR and source fingerprint reconciled. See [publication evidence](docs/testing/261016_GitHub_Publication_v1.0.md).
- **G1 SCOPED:** approved owner direction narrowed by [architecture](docs/architecture/001-prototype-foundation.md) to this six-file preparation foundation; one Level 3 domain.
- **G2 DEFINED:** [test contract](docs/testing/FOUNDATION_TEST_CONTRACT.md) defined before initial production changes; added negative tests verify the existing contract.
- **G3 VERIFIED LOCALLY:** shared models/codec, preparation views, package integration and OS 27 deployment changes implemented within scope.
- **G4 VERIFIED WITH LIMITS:** core 29-test suite, both Release builds, iPhone suite (seven executions) and full Watch scheme (12 executions) passed without failures. Generated app tests remain placeholder/launch smoke evidence; no physical or recording claim follows. See [evidence](docs/testing/261016_Foundation_Local_Evidence_v1.0.md).
- **G5 NOT RUN:** CI for an exact approved pushed HEAD remains open.
- **G6 NOT RUN:** independent review of committed HEAD remains open. Implementation review is not the independent final verdict.
- **G7 NOT RUN:** no physical iPhone/Watch evidence; simulator results do not establish installation, sensor, connectivity, battery or court feasibility.
- **G8 DRAFT PUBLISHED:** foundation committed and pushed to the feature branch; draft PR #1 open. CI, independent review and physical gates remain open. Merge and release are unauthorized.

## One next action

A new independent reviewer inspects the final committed PR HEAD without modifying files. CI and relevant physical-device evidence remain open; no merge-ready claim is made. Recording requires a subsequent bounded capture contract and implementation package.

## Latest bounded increment — physical-test preparation, 17 October 2026

Owner direction: prepare physical testing using Astra High. Allowed additions are `.github/workflows/foundation.yml`, the physical runbook and supporting testing/handover/gate/changelog updates only. Runtime source, tests, project configuration, permissions, entitlements, signing identities and source fingerprint remain unchanged. No capture implementation is in scope.

Signed generic-device builds for both apps and signature/profile checks passed. iPhone 15 Pro / iOS 27.2 (24B5099f) and Watch Ultra 2 / watchOS 27.0 (24R364) were visible and available in Xcode; actual installation, launch and interactive acceptance remain unperformed. Raw device/signing details stay private locally.

The prior independent review of `9f91550755eb5d317a6603ebb0ebf1eab19bcaaa` found no blocking code defect but was BLOCKED on CI/physical gates. New workflow/documentation changes require a refreshed exact-HEAD review. This section supersedes the old pre-review G6 pending wording above.

Current entry gates: G5 hosted CI pending; G6 refreshed committed-HEAD review pending; G7 physical acceptance not run. Next action: publish this preparation increment to the existing draft PR and obtain CI results. Keep the PR draft; no merge-ready verdict or physical success claim.

## Current increment — unified premium UI, 17 October 2026

Owner requests blue/yellow/white, modern premium presentation and Liquid Glass where appropriate on all implemented pages/subpages. [UI contract](docs/design/261017_Blue_Yellow_White_UI_Contract_v1.0.md) defines inventory, allowed production files, risk boundary and tests before implementation. Astra High implements this bounded Level2 presentation increment; PadelCore, recording/signing/permissions/CI behavior remain unchanged. Physical installation is on explicit owner hold pending simulator UI review. New source requires new builds, tests, fingerprint and independent exact-HEAD review; prior results are historical.

### Current verification, superseding earlier UI statuses

The [UI evidence](docs/testing/261017_PremiumUI_Local_Evidence_v1.0.md) and [25-file source manifest](docs/testing/261017_PremiumUI_Code_State.sha256) identify this increment. G0 reconciled local/remote cfea609, draftPR1, unchanged main f21bfab before publication. G1/G2 scoped by the UI contract; G3 five production files implemented. G4 core29, both final Release builds, three targeted phone flows and full14-execution phone/Watch suite passed. Failed Watch attempts01–03 and alternate phone/capture problems are retained, with fixes/limits documented.

G5 remains blocked by hosted Watch runtime-profile failure on prior HEAD; fresh current CI must be inspected. G6 requires new independent exact-HEAD review. G7 physical installation is explicitly on owner hold, and earlier signed artifacts do not identify this new source. G8 remains draft/unmerged. Dark rendering and complete landscape visual acceptance remain open; Mac lock prevents finishing final live preview arrangement and restoring Reduce Transparency.

**One next action:** owner unlocks the Mac to finish simulator UI review. This is a preparation UI preview, not a recording or release-ready app.
