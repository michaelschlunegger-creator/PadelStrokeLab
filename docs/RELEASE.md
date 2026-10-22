# Development installation and release gates

The three software findings on the original published `7d5dc2a` candidate are addressed by the [bounded privacy corrections](testing/261022_Privacy_Readiness_Corrections_Verification_v1.0.md). The current 115-input portable manifest SHA256 is `58fc81d73add11d9373ade24a9dba344e57330f9d8afc834c8999c83cadcca93`. Live exact-commit CI, independent review and separate installation observations belong in [PR #3](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/3) and its linked evidence; a locally passing suite does not establish those later gates. This keeps observations attached to the tested source without changing it merely to record subsequent device outcomes.

This is a development candidate for owner forehand/backhand recording, not a TestFlight or App Store release. The bundle identifiers and companion relationship remain unchanged; display name is Padel Master.

## Candidate

- Branch: `feature/guided-padel-setup`, stacked on `feature/watch-recording-storage` (`bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`).
- iPhone and embedded Watch products: version 1.0, build 6. Exact portable inputs are in the [manifest](testing/261022_Owner_First_Final_Code_State.sha256); private evidence also records signed executable hashes.
- [Local verification](testing/261022_Owner_First_Final_Local_Verification_v1.0.md) and [independent local source review](reviews/261022_Owner_First_Final_Local_Review_v1.0.md) distinguish source acceptance from physical evidence.
- Signed generic-device build, deep/strict signature verification, current provisioning and coverage of the baseline devices are verified locally. Provisioning identifiers and personal device details are retained privately.

## Before installation/testing

Verify the published source, exact-head CI and independent committed-source review; resolve software blockers. Confirm Xcode has a live paired iPhone/Watch development connection. Install and verify each device separately, then use the [physical runbook](testing/261021_Owner_Forehand_Backhand_Physical_Runbook_v1.0.md). Install/launch success alone is not a passed recording test. The current PR/checks and Gate Card carry changing CI and device observations.

Start with a controlled dry run and a verified phone export before collecting forehand/backhand contacts. Confirm fresh playing-arm placement and owner consent. Preserve originals and interrupted evidence; do not delete data to conceal a failed test. Retain the previous source/build for diagnosis; do not automatically migrate, erase or overwrite recordings as a recovery shortcut.

Merge requires separate owner approval and all applicable gates. App Store/TestFlight distribution, generalized recognition/quality claims and guest collection remain separate decisions. Never submit or release merely because this development candidate installs.

[Core fixture portability and CI budgeting](testing/261023_Core_CI_Portability_v1.0.md) records the subsequent test-only/environment correction and preserved first CI failure. App production and signed products retain identical inputs.
