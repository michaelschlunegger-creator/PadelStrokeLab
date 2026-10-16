# Testing

Updated 16 October 2026. The bounded preparation foundation uses Xcode 27.0 (27A266a), Swift 6.4 and iOS/watchOS 27 SDKs. All commands explicitly select /Applications/Xcode.app/Contents/Developer; generated output stays outside the source/Drive folders.

The shared model suite covers constructors and decoding, unsupported meanings/schemas, identity/revision/attempt conflicts, notes, malformed metadata, deterministic round trips and archive size bounds. These tests do not prove sensor timing, durable storage, Watch transfer or motion classification.

Both existing app schemes have Release simulator builds and full simulator suite commands in [the local evidence record](testing/261016_Foundation_Local_Evidence_v1.0.md). The generated app unit tests contain placeholder examples; the UI suites only exercise launches and template launch performance. Their success is smoke evidence, not confirmation of playing-arm interaction, accessibility, battery, physical pairing or recorder readiness. Meaningful metadata tests run separately in PadelCore.

[The test contract](testing/FOUNDATION_TEST_CONTRACT.md) was defined before the initial production changes. [The source manifest](testing/261016_Foundation_Code_State.sha256) identifies 22 source/configuration/asset files for the foundation source state. Affected source/configuration edits invalidate their evidence. CI and independent review must later run against the exact approved committed HEAD.

No physical iPhone or Watch tests have been performed here. Relevant physical evidence and owner acceptance remain mandatory before readiness/merge claims.

## Publication identity

The local evidence record predates the initial foundation commit. Its source manifest is rechecked before publication; documentation-only publication updates do not change those 22 tested files. Exact implementation commit and publication verification are recorded in [the handover](HANDOVER.md). Raw result bundles/logs remain local; summaries in this repository are the development evidence record.
