# Foundation test contract

Defined before production changes, 16 October 2026.

## Shared metadata and labels

Verify production constructors and decoding reject zero/negative attempt numbers and revisions; conflicting attempt ordinals; duplicate label identifiers/revisions; unsupported schema/category/origin; invalid dates; overlong notes; and oversized input.

Verify stable IDs, self-assessment provenance, uncertainty/non-contact categories, label revision history, timestamps and Unicode notes survive round trips. Reordering equivalent label histories produces identical encoded bytes. Blank notes normalize without changing the recorded category.

These tests concern metadata only. They do not prove storage durability, timestamp fidelity, motion classification or actual sensor availability.

## Platform and application checks

- Confirm all phone/test deployment settings use 27.0 and all Watch/test settings use 27.0.
- Compile the shared package under the installed Xcode 27 Swift toolchain.
- Build both existing application schemes in Release for iOS/watchOS 27 simulators.
- Run the existing phone and Watch test suites on OS 27 simulators, without automatic retries. Preserve failures and exact commands.
- Preserve the generated bundle identifiers, six targets and signing team. Do not acquire new entitlements or request device permissions.
- Check the diff for unrelated changes and verify that the adopted older PDF checksum is unchanged.

## Interpretation

The apps explicitly identify this build as preparation only. No motion recording or quality score is available. Passing simulator tests does not establish physical-device readiness. Any source/configuration change invalidates affected evidence and requires rerunning the affected checks.
