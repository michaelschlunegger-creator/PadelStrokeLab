# Logger build 4 installation checkpoint — v1.0

20 October 2026. This records the preceding logger baseline, not verification of the new guided setup wizard.

## Source and automated evidence

- Repository: `michaelschlunegger-creator/PadelStrokeLab`.
- Baseline branch: `feature/watch-recording-storage`.
- Reviewed, pushed commit: `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`.
- Draft [PR #2](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/2), base `chore/project-governance`; no merge occurred.
- [Exact-HEAD CI](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39276367832/job/118141587943): completed/success. All steps succeeded. The single Node 20/24 Actions-runtime deprecation annotation is non-blocking and unrelated to app runtime.
- Artifact `foundation-39276367832-1`, ID `12199909247`, 46,388,530 bytes, SHA-256 `ec9e65e4052712e2c78144e43f7ed2438f5c1e1a2298ff213b44d8bde8fd0fa8`. Downloaded hash and CRC independently verified by Astra Extra High.
- Artifact preflight identifies the exact commit, all 55 source-manifest entries passing, Xcode 27.0/27A266a, Swift 6.4 and OS 27 SDKs.
- Artifact results: 108 core tests, 8 phone app-host tests, 9 phone UI executions, 23 Watch app-host tests, 8 Watch UI executions and both Release builds passed. The Watch invocation also repeats the phone-target checks. These counts identify unique suites, not an inflated sum of repeated executions.
- Separate independent Astra Extra High source audit and gate refresh found no source/pre-install blockers. Its merge verdict remains BLOCKED by missing physical behavior evidence and owner merge approval.

## Physical installation observations

The owner authorized installation and subsequently confirmed both apps launched. At 06:36 UTC / 10:36 Dubai time on 20 October, separate device receipts establish:

| Device | OS | Installation | Queried version/build | Launch |
| --- | --- | --- | --- | --- |
| iPhone 15 Pro | iOS 27.2 | success | 1.0 / 4 | success |
| Apple Watch Ultra 2 | watchOS 27.0.1 | success | 1.0 / 4 | success |

Both devices were reachable and unlocked for installation. Deep/strict signature verification passed separately for both app bundles; development profiles were unexpired. Fresh executable hashes matched the reviewed signed build:

- Phone: `a4852c302b205a7fabb970cd0c35b7c424578e3a28006585034b16c1fce705a6`.
- Watch: `7f86f23558ac9c220a45676d3baa5a9ac23b9cc6ef0ad0b7a39841356fd5ee4c`.

Private receipts are retained under the existing DerivedData `complete-training` evidence folder: final CI receipt 47; phone install/version/launch 48/49/52; Watch install/version/launch 50/51/53; sanitized installation summary 54. Hardware identifiers, provisioning details and raw device logs are not committed.

## Explicit limits and next package

Actual motion samples, permissions/workout behavior, wrist placement, paired application receipt, export read-back, recovery, battery and accessibility have not been observed on this baseline. No reliable clean-hit or automatic-shot claim follows from installation or simulator tests. Physical G7 remains open; merge/release remain unauthorized.

Before the first physical recording, the owner requested and approved a mandatory ordered preparation wizard beginning with **Let’s Play**. That change is being implemented and must be verified separately on `feature/guided-padel-setup`. This baseline's passing automation cannot be used as evidence that the new source passes. Physical replacement requires new verification and the previously requested simulator UI review.
