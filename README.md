# PadelStrokeLab

An iPhone and Apple Watch prototype investigating whether Watch signals can predict the owner's perceived clean contacts and mishits across separate practice sessions. The Watch belongs on the playing/racket arm.

## Current state

The local Stage 1 logger implements explicit Watch motion recording with live sample counts, pause/resume/stop, bounded durable storage and interruption recovery. Watch originals can transfer to iPhone with a separate verified application receipt. The phone supports coverage review, owner labels with revision history, export and confirmed local deletion. The shared blue/yellow/white theme uses native Liquid Glass where appropriate. **Physical capture, background continuity and real Watch-to-phone delivery remain unverified. There is no automatic shot-quality score.**

The logger is saved in GitHub on `feature/watch-recording-storage`, source implementation commit `2c05afc0419b5221726705240cd1f18f45e3a982`, based on foundation `ee15c0e` under the owner-approved dependent-branch exception. Separate foundation [draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1) remains unmerged. See [publication verification](docs/testing/261019_Logger_GitHub_Publication_v1.0.md), [Gate Card](GATE_CARD.md), [Plan](docs/PLAN.md), [Testing](docs/TESTING.md), [local logger evidence](docs/testing/261019_Physical_Logger_Local_Evidence_v1.0.md) and [first-set runbook](docs/testing/261019_Physical_Shot_Logger_Runbook_v1.0.md). Current hosted CI, committed-HEAD independent review and physical observations remain open.

## Authority

[Product Authority](docs/PRODUCT_AUTHORITY.md) adopts App Specifications `PSL-SPEC-001 v1.1` and the retained iOS/watchOS 27 requirement. The older v2.0 PDF is immutable historical reference. Initial feasibility uses normal practice and owner labels; no paid coach or large participant study is mandatory.

[Engineering Governance](ENGINEERING_GOVERNANCE.md) controls scope, tests, review and approvals. GitHub is the source of truth for code, development documents, decisions, test evidence and review. Google Drive retains the user-facing specifications and Word documents. Xcode uses the local Git checkout; no active source relocation to Drive is planned. See [storage decision](docs/adr/002-source-of-truth.md).

## Build and test

Use Xcode 27.0 with iOS and watchOS 27 SDKs. Open `PadelStrokeLab.xcodeproj`; schemes are `PadelStrokeLab` and `PadelStrokeLab Watch App`. Both apps use local `Packages/PadelCore` (metadata and recording storage) and `Packages/PadelDesign` (SwiftUI presentation), without third-party dependencies. Xcode 27 opens simulated devices in Device Hub.

For command-line operations set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Store DerivedData and result bundles outside the source and synced Drive folders. The full commands and limits are in [Testing](docs/TESTING.md).

The Watch requests motion access and HealthKit workout sharing access to support explicit background recording. No Health read access or saved workout summary is requested; system activity metrics may still change. The first tester visibly limits each set to 120 active seconds. Both apps have a signed build 3 after review corrections. See the [review-fix evidence](docs/testing/261019_Logger_Review_Fix_Evidence_v1.0.md) for current tests and limits. Physical installation and remaining CI/review/physical gates are open. The current structured drill is forehand-only; the owner’s broader training requirement is recorded in the [draft expansion plan](docs/architecture/261019_Broader_Training_Readiness_Plan_v1.0.md), pending confirmation/approval.
