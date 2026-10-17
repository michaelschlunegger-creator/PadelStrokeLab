# Testing

Updated 16 October 2026. The bounded preparation foundation uses Xcode 27.0 (27A266a), Swift 6.4 and iOS/watchOS 27 SDKs. All commands explicitly select /Applications/Xcode.app/Contents/Developer; generated output stays outside the source/Drive folders.

The shared model suite covers constructors and decoding, unsupported meanings/schemas, identity/revision/attempt conflicts, notes, malformed metadata, deterministic round trips and archive size bounds. These tests do not prove sensor timing, durable storage, Watch transfer or motion classification.

Both existing app schemes have Release simulator builds and full simulator suite commands in [the local evidence record](testing/261016_Foundation_Local_Evidence_v1.0.md). The generated app unit tests contain placeholder examples; the UI suites only exercise launches and template launch performance. Their success is smoke evidence, not confirmation of playing-arm interaction, accessibility, battery, physical pairing or recorder readiness. Meaningful metadata tests run separately in PadelCore.

[The test contract](testing/FOUNDATION_TEST_CONTRACT.md) was defined before the initial production changes. [The source manifest](testing/261016_Foundation_Code_State.sha256) identifies 22 source/configuration/asset files for the foundation source state. Affected source/configuration edits invalidate their evidence. CI and independent review must later run against the exact approved committed HEAD.

No physical iPhone or Watch tests have been performed here. Relevant physical evidence and owner acceptance remain mandatory before readiness/merge claims.

## Publication identity

The local evidence record predates the initial foundation commit. Its source manifest is rechecked before publication; documentation-only publication updates do not change those 22 tested files. Exact implementation commit and publication verification are recorded in [the handover](HANDOVER.md). Raw result bundles/logs remain local; summaries in this repository are the development evidence record.

## Physical foundation preparation — 17 October 2026

[Physical foundation runbook](testing/261017_Physical_Foundation_Runbook_v1.0.md) bounds the device checks to installation, launch, playing-arm setup and honest preparation-only messaging. The GitHub `Foundation checks` workflow reproduces core tests, both Release simulator builds and both existing full simulator suites on Xcode/OS 27; artifacts retain failure evidence without retries.

Both generic physical Debug builds passed with existing signing settings and no provisioning updates. Signatures verified, and existing profiles include the observed iPhone and Watch. Device/profile identifiers and raw signing/connection logs stay outside this public repository. Installation, launch and human observations are not yet evidence. Run status and exact reviewed branch HEAD are recorded in draft PR #1; CI and refreshed independent review must precede the physical acceptance run.

## Unified UI increment — 17 October 2026

The [UI contract](design/261017_Blue_Yellow_White_UI_Contract_v1.0.md) defines visual scope and acceptance before implementation. [Premium UI source identity](testing/261017_PremiumUI_Code_State.sha256) replaces the old foundation manifest for current CI verification; the older manifest/evidence remain immutable historical records. UI/source changes invalidate previous affected build/review results.

Existing empty UI examples are replaced by meaningful guide/back-navigation and Watch arm/confirmation/relaunch workflows, preserving the full suite and launch-performance coverage. Screenshot attachments record the actual simulator interface. Physical installation remains on owner hold. Current UI evidence and remaining limits are recorded in the new UI evidence report when the runs finish.

## Current premium UI evidence — 17 October 2026

[Detailed evidence](testing/261017_PremiumUI_Local_Evidence_v1.0.md) supersedes older UI/build claims for this increment. Source fingerprint: [25-file manifest](testing/261017_PremiumUI_Code_State.sha256). Core29, both final Release builds and full phone/Watch scheme14 executions passed. Meaningful phone navigation and Watch confirmation regressions supplement generated smoke tests. Failed attempts/capture defects remain recorded. Dark rendering, complete landscape visual audit, Watch large text and physical usability remain unverified. Physical installation is on owner hold until simulator UI review; the Mac locked during final preview arrangement.

The subsequent [Watch contrast correction](testing/261017_Watch_Navigation_Contrast_Evidence_v1.0.md) supersedes affected builds/Watch results: both Release products rebuilt successfully, all five Watch test executions passed, new picker capture inspected. Per-file hashes preserve the unchanged phone/core test evidence; no full14-execution run is claimed for the changed Watch source.
