# Delivery plan

Updated 16 October 2026. Authority: [PSL-SPEC-001 v1.1](PRODUCT_AUTHORITY.md).

The approved seven stages are: personal recording tester; contact-signal feasibility; useful personal training companion; validated expansion; social/community foundation; fair challenges/rankings; and coordination/provider integrations. Each stage depends on its own evidence and approved scope.

## Current bounded increment

The preparation foundation supports WP1 without completing it. It covers six production files: package manifest, two shared model/codec sources, two preparation views and Xcode project integration. No sensor, workout, transport, durable session, AI or community implementation is included.

Local metadata tests and simulator builds/suites are recorded in [Testing](TESTING.md). CI, committed-HEAD independent review, relevant physical validation and approved merge remain open.

## Next increment

Define and review the smallest owner recording package before changing capture code. Specify Watch session authority, explicit start/stop states, sensor availability and observed rates, workout/resource ownership, monotonic timing, bounded durable writes, interruption/recovery, data completeness and safe saved-state semantics. Split transfer/export if the package would exceed eight production files, 2,500 changed lines or two Risk Level 3 domains.

The owner supplies a practical clean-contact/mishit rubric distinguishing contact feel from shot outcome and technique. Record timing, confidence and source evidence in the future label format, preserve uncertain/non-contact attempts and allow blinded repeat labels. Start with normal practice and simple signal inspection; formal held-out evaluation criteria are ratified before tuning against evaluation sessions.

Do not turn proposed collection sizes, accuracy thresholds or the older PDF's study assumptions into mandatory personal pilot gates. Any outside expense requires a concrete question and separate approval.

## Open dependencies

- Physical iPhone 15 Pro / Watch Ultra 2 OS builds, pairing, signing/install and capabilities.
- Approved capture architecture and test contract; no sensor evidence yet.
- Exact owner rubric and first short court protocol.
- GitHub is the development source of truth; the active Xcode checkout remains local. See [ADR 002](adr/002-source-of-truth.md).
- Initial foundation publication is owner-authorized; independent exact-HEAD review, clean CI, physical evidence and later merge approval remain open.

## GitHub publication

Foundation implementation commit `7ae8a9855a52251b588e7cc4cb7ab2aa1fd7ebd0` is pushed on `chore/project-governance`; [draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1) is open. Documentation-only follow-ups preserve the tested source manifest. CI, independent exact-HEAD review, physical evidence and owner-approved merge remain open. Source synchronization to Drive is superseded by ADR 002.
