# Prototype foundation — 16 October 2026

## Authority and bounded scope

The owner instructed implementation from App Specifications `PSL-SPEC-001 v1.1` and confirmed that the existing test devices run current OS versions. Use iOS/watchOS 27 as required by the earlier recorded platform amendment. Exact physical OS/build and runtime sensor support remain unverified; they do not block this simulator-only foundation package.

This package establishes a local Swift package for practice metadata and owner labels, playing-arm preparation screens, and the required deployment configuration. It does not capture motion, start workouts, transport data, persist recordings, generate scores, or enable AI/community services. The generated app structure and signing identity are retained.

## Contract

- `PadelCore` is an Apple-platform-independent value-model library shared by the phone and Watch apps. It has no external dependencies.
- A practice metadata record is not a recorded session and must never imply captured sensor evidence.
- Identifiers and label provenance survive serialization. Self labels remain explicitly self assessments.
- Labels distinguish contact quality, uncertainty, air swings and non-stroke activity; they do not encode match outcome or diagnose technique.
- Attempt numbers and revision numbers must be positive. Different attempts cannot share an ordinal. Revisions for one attempt retain its ordinal and are individually identified.
- Unknown schemas/categories, contradictory identifiers and malformed metadata are rejected instead of silently coerced.
- Metadata encoding is deterministic and bounded. Raw sensor streams will use a separately reviewed format.
- The Watch prepares playing-arm selection and confirmation. Changing the arm clears its confirmation. No control in this build claims to start a recording.

## Files and risk boundary

Production files: the local package manifest, `PracticeModels.swift`, `PracticeArchive.swift`, both existing `ContentView.swift` files and `project.pbxproj` (six files; below the eight-file limit). Test and documentation changes support this exact scope.

This package has no sensor, workout, background, transport, cloud, permission or active-recording concurrency domain. Metadata validation and its serialized representation require integrity tests. Real capture, durable checkpoints and transfer are separate future packages with their own contracts.

## Follow-on architecture, not implemented here

The Watch should own the active capture and original recording; the phone should receive verified copies and support labels/review. File durability, timestamp mapping, gap rules, recovery and transfer acknowledgements require their own test contract before implementation. This foundation does not decide their implementation or claim those gates passed.

## Evidence and approval

The latest owner direction authorizes progressing with setup rather than waiting for devices. No commit, push, PR, merge or release is authorized by this package. Builds/tests use Xcode 27 only, with generated outputs outside the Drive-backed project folders. Physical feasibility remains open.
