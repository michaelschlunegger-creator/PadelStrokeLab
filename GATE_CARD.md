# Active Gate Card

Updated 16 October 2026, Asia/Dubai. Prior bootstrap gate is preserved [unchanged as history](docs/history/260824_Governance_Gate_Card_v1.0.md).

## Package and authority

Task: first preparation foundation for WP1, following owner authorization to start from `PSL-SPEC-001 v1.1`. The owner requested Astra with Extra High reasoning for foundational coding; implementation review is separate from the future independent committed-HEAD review.

Risk: Level 3 for preliminary metadata integrity/serialization, bounded to one domain. No sensor/workout, transport, persistence of recordings, concurrent capture, scoring or AI implementation.

Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`. Branch: `chore/project-governance`. HEAD/base/local and live remote main: `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; ahead/behind 0/0; no upstream; no PR. Origin: https://github.com/michaelschlunegger-creator/PadelStrokeLab.git.

The existing generated project/governance files were already untracked and README already modified before foundation work. All remain uncommitted; no main edit, commit, push, PR, merge or release occurred. Exact tested source is identified by [the source manifest](docs/testing/261016_Foundation_Code_State.sha256), SHA-256 `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`.

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

- **G0 VERIFIED:** repository, branch/base/remote, 0/0 state, uncommitted scope, no PR and exact source fingerprint reconciled.
- **G1 SCOPED:** approved owner direction narrowed by [architecture](docs/architecture/001-prototype-foundation.md) to this six-file preparation foundation; one Level 3 domain.
- **G2 DEFINED:** [test contract](docs/testing/FOUNDATION_TEST_CONTRACT.md) defined before initial production changes; added negative tests verify the existing contract.
- **G3 VERIFIED LOCALLY:** shared models/codec, preparation views, package integration and OS 27 deployment changes implemented within scope.
- **G4 VERIFIED WITH LIMITS:** core 29-test suite, both Release builds, iPhone suite (seven executions) and full Watch scheme (12 executions) passed without failures. Generated app tests remain placeholder/launch smoke evidence; no physical or recording claim follows. See [evidence](docs/testing/261016_Foundation_Local_Evidence_v1.0.md).
- **G5 NOT RUN:** CI for an exact approved pushed HEAD remains open.
- **G6 NOT RUN:** independent review of committed HEAD remains open. Implementation review is not the independent final verdict.
- **G7 NOT RUN:** no physical iPhone/Watch evidence; simulator results do not establish installation, sensor, connectivity, battery or court feasibility.
- **G8 PUBLICATION AUTHORIZED:** the owner directed saving the foundation in GitHub. Commit/push and a draft review PR are in scope; merge and release remain unauthorized.

## One next action

Publish the owner-authorized foundation on `chore/project-governance`, record its exact commit and open a draft pull request. Independent committed-HEAD review, clean CI and relevant physical-device evidence remain required; no merge-ready claim is made. [ADR 002](docs/adr/002-source-of-truth.md) records the owner’s storage decision.
