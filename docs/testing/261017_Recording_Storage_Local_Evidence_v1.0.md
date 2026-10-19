# Recording storage package A — local evidence

17 October 2026, Asia/Dubai. Local/uncommitted implementation; **not merge-ready or court-ready**.

## Authority and exact source

Owner approved the [plan](../architecture/261017_Watch_Motion_Recording_Plan_v1.0.md), first-package [test contract](261017_Watch_Recording_Test_Contract_v1.0.md) and dependent branch by replying “ok, add the code.” Architecture: Astra Extra High review; bounded implementation: Astra High; parent inspected production paths, requested the final-manifest readback and valid-checksum decoder regression, independently built both app schemes and verified the final logs/fingerprints. This does not substitute for independent committed-HEAD code review.

Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`. Local branch `feature/watch-recording-storage`, no upstream, based on `ee15c0ef86c99064bb1295c7550fba1daea66a3c`. No new commit, push, PR, merge, install or release. Foundation draft PR1 remains separate and unmerged; its hosted run 39031993296 was cancelled. Remote main remains `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8` at preflight.

[31-file source manifest](261017_Recording_Storage_Code_State.sha256), SHA-256 `cd3f1430c77ffa59aa5aefa0b22b76a6b202b2c5acd8cdaaa680c8aef565bc01`. All 31 hashes verified after the final test run. This extends the previous 25-file source inventory with six new Swift files; the historical manifest is unchanged. Production hashes stayed unchanged throughout both Release builds and the final test-only regression addition.

Production changes: three new core files, 792 lines: `RecordingModels.swift` (259), `RecordingChunkCodec.swift` (139), `RecordingStore.swift` (394). Three new test files support those paths. Existing practice schemas/codec, package manifest, app sources/UI, project configuration, signing, entitlements, permissions and CI workflow are unchanged. No third-party dependency was added.

## Implemented behavior and limits

- Explicit supplied setup/build/device/capability metadata, original per-stream source timestamps, clock-domain ID and separate wall-clock anchor. No sensor discovery or rate measurement occurs in storage.
- Deterministic versioned binary chunks, strict finite/ordered values, declared channels/units, original double bit patterns, exact identities/sequences/counts/bounds and SHA-256 integrity checks. Checksums detect accidental corruption; they do not authenticate a maliciously rewritten archive.
- Synchronous, single-trusted-caller store: exclusive session/chunk creation, short-write handling, checked file/directory synchronization, atomic manifests and readback after manifest publication. Finalization rereads stored data before returning retained coverage. Writer errors prevent further capture appends.
- Read-only bounded recovery retains original partial/corrupt/orphan evidence, reports inconsistencies and never fabricates a missing finalization. A finalized storage record describes verified retained bytes; stop reason and boundaries remain separate from uninterrupted signal coverage. Reopening is inspection-only, never continuation in a new boot clock.
- Root must be an existing absolute directory with no symlink/traversal components. Test fixtures use POSIX `realpath` after directory creation because Foundation path resolution retained the `/var` alias on this Mac. Files/directories use 0600/0700. Host tests do not establish physical Watch sandbox/data-protection usability.
- Engineering caps: 1 MiB per chunk; 32,764 accelerometer or 9,361 device-motion samples per chunk; 256 chunks total; metadata 16 KiB; manifest 256 KiB; text 128 UTF-8 bytes; recovery 272 entries and 268,976,128 bytes, one decoded chunk at a time. These are defensive limits, not duration/rate/battery claims. Future live batching/checkpoint policy must fit or explicitly revise these bounds before implementation.

## Commands and outcomes

Toolchain reverified: Xcode 27.0 (27A266a), Apple Swift 6.4, iOS/watchOS 27.0 SDKs. Every command selects `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; global Xcode selection is unchanged.

From repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/PadelCore --scratch-path /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-RecordingStorage/package
```

Final outcome: **64 Swift Testing tests across four suites passed, exit 0**, including all existing 29 core tests and 35 recording tests. XCTest's separate zero-test line is not the Swift Testing count. Final log `logs/06-full-after-decoder-regression.log`; preceding full run `05-full-package.log` passed 63 tests before the additional decoder regression. Targeted commands add `--filter Recording`.

Both Release builds passed, exit 0:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PadelStrokeLab.xcodeproj -scheme PadelStrokeLab -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-RecordingStorage-phone CODE_SIGNING_ALLOWED=NO build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PadelStrokeLab.xcodeproj -scheme 'PadelStrokeLab Watch App' -configuration Release -destination 'generic/platform=watchOS Simulator' -derivedDataPath /Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-RecordingStorage-watch CODE_SIGNING_ALLOWED=NO build
```

Build logs: `parent-evidence/phone-release-01.log`, `parent-evidence/watch-release-01.log`. Both contain `BUILD SUCCEEDED`. AppIntents metadata extraction was skipped because the apps have no AppIntents dependency; no compilation error is present. There was no app launch/install or UI suite rerun in this package.

All local logs/scratch outputs live under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-RecordingStorage/`, outside Git and synced project folders. Separate app build outputs use the `-phone` and `-watch` sibling paths above. Source manifest verification and `git diff --check` pass.

## Failure history and corrections

No automatic test retry was used. Preserve:

| Log | Result and reason |
|---|---|
| `logs/01-targeted.log` | Initial 34-test run failed with 39 issues. Models/codec passed; storage fixtures supplied a `/var` symlink path rejected by production no-follow protection. Child runner invocation also selected no helper work. |
| `logs/02-helper-diagnostic.log` | Helper-only diagnostic; observed runner layout, not storage acceptance. |
| `logs/03-root-and-runner-diagnostic.log` | Narrow corrected-fixture/runner diagnosis passed. Fixtures use POSIX canonical roots; child invocation preserves the actual SwiftPM helper/bundle arguments. Production safety checks were unchanged. |
| `logs/04-targeted-after-fixture-fixes.log` | All 34 recording tests passed after the two test-harness corrections. |
| `logs/05-full-package.log` | All 63 tests passed. |
| `logs/06-full-after-decoder-regression.log` | All 64 tests passed after adding malformed headers/payloads with valid recomputed checksums. This exercises decoder validation beyond checksum rejection. |

Read-only probes of an obsolete runner layout are preserved in `logs/diagnostic-failures.txt`. No failing acceptance result was hidden or weakened.

## Acceptance and remaining gates

| Area | Status |
|---|---|
| G0 authority / branch exception | VERIFIED locally, with owner-approved dependency on unmerged foundation. |
| G1/G2 scope / tests | APPROVED and bounded before production changes. |
| G3 implementation | VERIFIED locally within three production files/two Level 3 domains. |
| G4 host codec/storage/recovery regression | VERIFIED: 64 tests; both Release simulator builds; exact source manifest. |
| Relevant physical Watch persistence | UNKNOWN: host tests and SDK builds cannot establish sandbox, protection, actual low storage or device interruption behavior. |
| G5 current CI | NOT RUN. Existing workflow fingerprint covers only historical foundation files; publication needs an explicitly scoped inventory update. |
| G6 independent committed-HEAD review | NOT RUN: new source is uncommitted. Architecture review/parent QA is not this gate. |
| G7 physical / G8 approved merge | NOT RUN / UNAUTHORIZED. |

Tests use synthetic data and real temporary filesystem operations. I/O faults are injected through internal seams while defaults remain real operations; no physical disk was filled. Four macOS child-process cuts exercise exit without Swift cleanup at write/publication/finalization boundaries. A valid final manifest found afterward may verify retained-data finalization, never uninterrupted capture. Power loss, hostile concurrent writers, physical Watch behavior and recovery of active HealthKit resources are not proven.

S1-03's core storage component is implemented locally; the app-level requirement and WP1 are not complete. No live sensors, workout/permissions, concurrency owner, Watch controls, transport/export, timestamped owner-label matching or scoring is implemented. Court collection requires those separately bounded increments and their evidence.

Next action: obtain authorization for committing/pushing the scoped branch and a draft PR; preserve the foundation dependency and do not merge prematurely. CI inventory work, independent committed-HEAD review and relevant physical evidence remain required before a merge-ready claim.
