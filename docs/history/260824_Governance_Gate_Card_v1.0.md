# Active Gate Card

Last updated: 2026-08-24, Asia/Dubai

## Task and risk

- **Task:** Bootstrap project-local Git governance and adopt `PSA-PRD-001 v2.0` as the canonical Product/Design Bible for the generated iPhone + Apple Watch project.
- **Current package risk:** Level 1 — documentation, immutable product-authority artifact, ignore rules, and local repository metadata only.
- **Future governed risk:** Level 3 for motion capture, WatchConnectivity, lifecycle/concurrency, evidence/export, and physical feasibility.

## Authority

- **Repository path:** `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`
- **Installed Xcode:** 26.5 (build 17F42) retained; Xcode 27.0 beta 5 (build 27A5237l) installed separately at `/Applications/Xcode-27-beta-5.app`, strict-signature verified and accepted by macOS as Apple System software
- **Required toolchain:** Xcode 27 is installed but not yet license-accepted or selected; iOS 27/watchOS 27 SDK verification is pending completion of first-launch setup
- **Project:** `PadelStrokeLab.xcodeproj`
- **Targets:** iPhone app, Watch app, and unit/UI test targets for both platforms (six targets total)
- **Schemes:** `PadelStrokeLab`; `PadelStrokeLab Watch App`
- **Product/design authority:** `docs/product/Padel_Performance_App_Product_Requirements_Design_Bible_v2.0_REDTEAM.pdf`
- **Authority record:** `docs/PRODUCT_AUTHORITY.md`
- **Design Bible identity:** `PSA-PRD-001 v2.0`, 67 PDF pages, SHA-256 `939c5858420124a4fe3753e3812c7ad594f3a2755c7225b7f2ebe6c13238af25`
- **Known platform blocker:** Bible and owner decision require iOS/watchOS 27 for every phase; installed Xcode and generated deployment targets are 26.5. No 26.5 exception and no target change are authorized in this package.
- **Host compatibility:** Apple silicon (`arm64`) on macOS 26.6; approximately 62 GiB free on the data volume, sufficient to proceed with the Xcode 27 download/install workflow.
- **Toolchain acquisition:** `Xcode_27_beta_5.xip`, `Command_Line_Tools_27_beta_5.dmg`, and `Icon_Composer_2_beta_5.dmg` completed. The Xcode XIP and Command Line Tools package are signed Apple Software; the Xcode app passed deep/strict signature verification. Command Line Tools 27 version `27.0.0.0.1786046012` and Icon Composer 2 version `2.0` (build 123) are installed. Additional Tools for Xcode 27 beta 5 is not downloaded or installed.
- **Recorded toolchain-check failures:** During the Command Line Tools transition, Apple system Git reported that the selected Command Line Tools could not locate the macOS SDK; the read-only repository facts remained available and the exact remote was separately reconciled. The first staged SDK query used a nonexistent app-internal `xcrun` path. The corrected system `xcrun` query reached Xcode 27 but was blocked because the Xcode license is not yet accepted. Re-run all three checks after first-launch setup; none of these checks changed project or Git state.
- **Git repository:** Initialized locally and connected to the verified GitHub repository
- **Branch:** `chore/project-governance`
- **Base:** `origin/main` at `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`
- **HEAD:** `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`
- **Upstream:** none
- **Remote:** `origin` → `https://github.com/michaelschlunegger-creator/PadelStrokeLab.git`
- **Remote HEAD:** `origin/main` at `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`
- **Ahead/behind vs. `origin/main`:** 0 / 0
- **Worktree:** tracked remote `README.md` modified; generated project, governance package, authority record, and versioned Design Bible remain untracked
- **PR:** none
- **Handover:** none

## Scope

Allowed files for this package:

- `AGENTS.md`
- `ENGINEERING_GOVERNANCE.md`
- `GATE_CARD.md`
- `.gitignore`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `README.md`
- `docs/PRODUCT_AUTHORITY.md`
- `docs/product/Padel_Performance_App_Product_Requirements_Design_Bible_v2.0_REDTEAM.pdf`
- local `.git/` metadata created by initialization

Forbidden in this package:

- Swift source or test changes
- `PadelStrokeLab.xcodeproj/project.pbxproj` changes
- build-setting, signing, capability, dependency, or scheme changes
- commits, remotes, pushes, PRs, merges, tags, or branch deletion
- builds, test runs, sensor work, WatchConnectivity work, and physical-device claims

## Invariants and non-goals

- The generated six-target project structure remains unchanged.
- The adopted PDF remains byte-for-byte identical to SHA-256 `939c5858420124a4fe3753e3812c7ad594f3a2755c7225b7f2ebe6c13238af25`.
- iOS 27 and watchOS 27 are mandatory for all future implementation, build, test, and evidence packages, including Phase 0.
- Xcode 26.5 and the 26.5 SDKs cannot be used as a fallback.
- No user-specific Xcode state is tracked.
- Local `main` is not created, checked out, or edited during the uncommitted bootstrap.
- No runtime, UI, signing, or bundle behavior changes.
- This package does not establish device roles or claim feasibility.

## Failure paths

- Initializing Git in the wrong directory would make repository authority ambiguous.
- Tracking `xcuserdata`, derived data, or build products would pollute the baseline.
- Checking out or changing `main` would violate the branch policy.
- Treating generated placeholder apps as validated would create false evidence.
- Implementing or collecting evidence with the current 26.5 toolchain would violate the mandatory platform baseline and create false platform evidence.
- Overwriting the adopted PDF without versioning would make product authority ambiguous.
- Committing without approval would violate the explicit Git control.

## Gate status

| Gate | Status | Evidence |
|---|---|---|
| G0 Authority | VERIFIED | Local branch, base, HEAD, remote HEAD, ahead/behind, worktree, changed scope, PR, and handover reconciled. |
| G1 Risk and scope | VERIFIED | Level 1 governance/adoption scope, immutable PDF identity, platform mismatch, and forbidden files recorded above. |
| G2 Test contract | NOT APPLICABLE | No production or test behavior changes. Structural verification is defined below. |
| G3 Implementation | VERIFIED | Governance files, authority record, immutable repository PDF copy, owner platform amendment, and repository links completed within allowed scope; no Swift, project, commit, or remote change. |
| G4 Local automation | VERIFIED WITH RECORDED NON-PRODUCT CHECK FAILURES | Source and repository PDFs are byte-identical at the recorded SHA-256; PDF metadata reports 67 pages with no encryption, form, or JavaScript; prior all-page render review remains valid for the identical bytes; `git diff --check` passed; Xcode user state is ignored; project and Swift files are trackable; live `origin/main`, local HEAD, and `origin/main` all equal `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; ahead/behind is 0/0; Xcode still lists six targets and two schemes. One read-only verification wrapper initially failed after assigning zsh's reserved `path` variable, which hid `rg` and `git` command lookup within that shell; it changed no artifacts, and the corrected wrapper passed. A later read-only Design Bible text check could not find the system `pdftotext` executable after storage cleanup; the bundled PDF runtime successfully performed the required check and confirmed the iOS/watchOS 27 statements. |
| G5 Clean CI | NOT APPLICABLE | Remote exists; CI is not configured or required for this uncommitted metadata package. |
| G6 Independent review | NOT APPLICABLE | Required later for committed Risk Level 3 changes. |
| G7 Physical devices | NOT APPLICABLE | No runtime behavior changed. |
| G8 PR/merge/closure | BLOCKED | First local project/governance commit and any push require explicit user approval; PR/merge remain out of scope. |

## Evidence validity

Current evidence applies only to the uncommitted worktree based on `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8` at the path above and the adopted PDF checksum recorded above. Any Swift, project, build-setting, dependency, signing, target, or Product/Design Bible change invalidates the corresponding baseline facts.

## Next action

Owner accepts the Xcode 27 license and authorizes first-launch component installation in the open Xcode window. Then select Xcode 27 and verify the iOS 27/watchOS 27 SDKs before changing project deployment targets. The first local project/governance/design-authority commit and any push still require separate explicit approval.
