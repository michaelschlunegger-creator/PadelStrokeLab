# Product authority

Updated 16 October 2026.

## Current authority and precedence

The current product authority is **App Specifications, PSL-SPEC-001 v1.1**, approved by the Product Owner on 16 October 2026. The owner subsequently instructed Codex to start implementation from this Scope of Works. The explicit existing **iOS 27 / watchOS 27** platform decision remains binding; D02's OS 26 suggestion in v1.1 was proposed, not an approved downgrade.

Source: https://docs.google.com/document/d/13yjwvbVenREb1uUZC6Q-bi5RV1EcIMTyHMH6Z8Fy86E/edit

Repository snapshot: [261016_App_Specifications_PSL-SPEC-001_v1.1.txt](product/261016_App_Specifications_PSL-SPEC-001_v1.1.txt). It preserves all 507 source paragraphs in order as plain text, separated by LF, without prose edits. Source revision identity is recorded in the adjacent [.source.json](product/261016_App_Specifications_PSL-SPEC-001_v1.1.source.json).

Snapshot SHA-256: `1a6d24e7bd33a823b90a77adef0c4f1787b1c8f054e4ce0cc61ec0e7f5890a8e`.

The approved direction is an owner-led personal feasibility experiment: Watch on the playing/racket arm, ordinary practice, owner self-reference labels, an uncertain category, repeat-label checks and separate-session evaluation. No paid coach, dedicated coaching session or large participant study is mandatory before personal signal evidence. Any paid outside input requires a specific unresolved question, deliverable, cap and owner approval. Self labels are not independent ground truth.

The seven-stage roadmap and this explicit direction are approved. Proposed metrics, collection sizes, final algorithms, new defaults and open decisions remain unapproved until resolved. Apple Intelligence is planned for explaining validated findings with an availability check and non-generative fallback; it is not measurement evidence.

## Historical reference

[PSA-PRD-001 v2.0 PDF](product/Padel_Performance_App_Product_Requirements_Design_Bible_v2.0_REDTEAM.pdf) remains an immutable historical design reference: 67 pages, SHA-256 `939c5858420124a4fe3753e3812c7ad594f3a2755c7225b7f2ebe6c13238af25`. It cannot override v1.1 or reintroduce superseded coach/study prerequisites.

The [prior authority record](history/260824_Product_Authority_v1.0.md) and [prior Gate Card](history/260824_Governance_Gate_Card_v1.0.md) are retained as dated history, including their then-current toolchain blockers. Their statuses are not current status.

## Verified platform and remaining unknowns

Xcode 27.0 (27A266a), Swift 6.4 and iOS/watchOS 27 SDKs were verified at `/Applications/Xcode.app`. Every Swift/Xcode command must use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, because the global selection remains CommandLineTools. All six app/test targets now require OS 27.0.

The owner confirms an iPhone 15 Pro and Apple Watch Ultra 2 on the latest OS, matching their LeftPhoneAlert devices. Exact physical OS/build, pairing, installation, permissions, orientation, sensor availability/rates and on-court usability have not been measured here. They block relevant physical claims, not bounded simulator foundation work.

The active checkout remains `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`. A verified pre-edit archive exists in the project Drive source-archive folder; this does not establish a Drive-hosted active Xcode working copy. Do not claim relocation/offline configuration is complete.

The [foundation architecture](architecture/001-prototype-foundation.md) and [test contract](testing/FOUNDATION_TEST_CONTRACT.md) bound the current package. It establishes preparation UI and preliminary label metadata only. It does not complete S1-01 or S1-05 and is not the WP1 recording app.

## Owner amendment — development storage, 16 October 2026

The owner explicitly directed that code be saved in GitHub. [ADR 002](adr/002-source-of-truth.md) records GitHub as the development source of truth and the local Git checkout as the active Xcode workspace. Google Drive retains user-facing specifications and Word documents. Earlier source archives are historical backups. This amendment does not change the product scope or approve a merge/release.

## Owner amendment — unified visual design, 17 October 2026

The owner requests blue, yellow and white, modern professional presentation and native Apple Liquid Glass where appropriate across every implemented page/subpage. The [design contract](design/261017_Blue_Yellow_White_UI_Contract_v1.0.md) bounds this preparation-only increment. Shared presentation tokens apply to phone and Watch; long reading surfaces remain opaque. The owner explicitly requests simulator UI review before any physical installation. This changes visual direction, not recording scope or release approval.


## Owner amendment — complete first-training workflows and shot types, 19 October 2026

After reviewing the proposed [broader first-training plan](architecture/261019_Broader_Training_Readiness_Plan_v1.1.md), the owner explicitly answered: “Yes, full training workflow and shot types”, and reinforced “Use astra for such essential stuff.” This approves expanding the first training logger beyond the original forehand-only drill, using selectable intended padel shot types and the complete setup/record/pause/resume/save/recover/transfer/review/label/export/delete workflow. It is not approval of automatic shot recognition, clean-hit scoring, long-duration match analysis, paid expertise, social features, merge or release.

Use Astra Extra High for the bounded architecture/risk review, Astra High implementation, and a separate independent committed-HEAD review. Preserve the original specification snapshot and old recordings. New collections must carry truthful manual drill/protocol metadata and remain distinguishable from the original forehand protocol. One intended shot type per short controlled set is the initial collection method; other movements remain explicitly unclassified. Actual installation remains conditional on pre-install readiness for real training recordings, followed by observed physical dry-run/transfer/export before court contacts. Short-set capture limits, playing-arm placement, owner self labels and all physical/measurement caveats remain binding.
