# PadelStrokeLab

An iPhone and Apple Watch prototype investigating whether Watch signals can predict the owner's perceived clean contacts and mishits across separate practice sessions. The Watch belongs on the playing/racket arm.

## Current state

The first local foundation contains preparation screens and a shared, tested Swift package for preliminary practice metadata and self-reference labels. **Recording controls, motion capture, durable sessions, transfer and scoring are not implemented.** No physical feasibility or general-player accuracy claim has been established.

Work is on `chore/project-governance`, based on `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. The foundation is saved in GitHub through [draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1); publication details are recorded in the handover. See [Gate Card](GATE_CARD.md), [Plan](docs/PLAN.md), [Testing](docs/TESTING.md) and [Handover](docs/HANDOVER.md) for exact evidence and remaining gates.

## Authority

[Product Authority](docs/PRODUCT_AUTHORITY.md) adopts App Specifications `PSL-SPEC-001 v1.1` and the retained iOS/watchOS 27 requirement. The older v2.0 PDF is immutable historical reference. Initial feasibility uses normal practice and owner labels; no paid coach or large participant study is mandatory.

[Engineering Governance](ENGINEERING_GOVERNANCE.md) controls scope, tests, review and approvals. GitHub is the source of truth for code, development documents, decisions, test evidence and review. Google Drive retains the user-facing specifications and Word documents. Xcode uses the local Git checkout; no active source relocation to Drive is planned. See [storage decision](docs/adr/002-source-of-truth.md).

## Build and test

Use Xcode 27.0 with iOS and watchOS 27 SDKs. Open `PadelStrokeLab.xcodeproj`; schemes are `PadelStrokeLab` and `PadelStrokeLab Watch App`. Both apps depend only on the local `Packages/PadelCore` package.

For command-line operations set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Store DerivedData and result bundles outside the source and synced Drive folders. The full commands and limits are in [Testing](docs/TESTING.md).

Physical device installation, entitlements, recording protocols and the required review gates remain subsequent work. This build requests no new permissions.
