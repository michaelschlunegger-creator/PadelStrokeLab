# Owner first build O1 — local evidence v1.0

21 October 2026. Implementation: GPT-6 Astra, Extra High reasoning. This is the released pure owner authority/context package, not the completed first build, a live wearer/Health guarantee, or merge readiness.

## Exact scope and source

Director release followed independent clearance of the [first-build contract](261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md), SHA-256 `f7666a8d73d5e11fa786571f294b9837d96d3768b30d9318b578ab8d762f706f`. Branch remains `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, intentional unpublished changes/no upstream. No Git publication, installation, simulator mutation or personal-data access occurred.

O1 adds exactly two production files under `Packages/PadelCore/Sources/PadelCore/`: `OwnerPracticeIdentity.swift` (291 lines) and `OwnerRecordingContext.swift` (156), **447 production lines** against the1,200-line/two-domain cap. Two matching new test files contain415 lines. All69 prior source/configuration/test inputs remain byte-identical. No app, existing test, project, permission, entitlement, raw codec/store or frozen P1 file changed.

The [73-entry final source manifest](261021_Owner_First_O1_Source_v1.0.sha256) has SHA-256 **`011867981ae4313fad0a94d11395611b4a49738ea261d1df453c9460de9d8549`**. Complete frozen file contents plus that manifest are preserved privately at `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/Checkpoints/01-o1-source.tar`, SHA-256 `723cb25d9336711cc242e66033e2b1ee393d9a41cab539ef17d602de0676587c`. Earlier checkpoints remain intact.

## Final evidence and retained failures

Raw logs and independent vectors are under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O1/`. `evidence.sha256` records their final bytes. Generated products stay outside the repository. Every Swift/Xcode invocation sets `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the version-only recheck returned Xcode27.0 (27A266a). Compilation uses installed OS27 SDKs. Xcode27.1/latest-patch compilation was not performed.

| Attempt | Result and significance |
| --- | --- |
| `01-tests-first-red.log` | Expected exit1: new tests referenced absent owner types before either production file existed. |
| `02-focused.log` | PASS10 new tests; initial implementation. Historical intermediate source. |
| `03-focused-boundaries.log` | PASS17 new tests, including canonical identity and semantic corruption cases. Historical intermediate source. |
| `04-full-core.log`, `06-final-core.log` | PASS156 tests/15 suites on intermediate source; superseded by the final run below. |
| `05-phone-release.log` | PASS initial phone Release; superseded by later source corrections. |
| `07-clock-rollback-red.log` | FAIL1 regression/one issue: a legitimate backward reported clock prevented HR-disable. Root review identified the cause. Revisions/generations now order authority; the finite reported timestamp is retained unchanged. |
| `08-final-core.log` | PASS157 tests/15 suites after clock correction; superseded by capacity/policy changes. |
| `09-revocation-capacity-red.log` | FAIL1 regression/two issues: the prior reserve could admit an active state lacking room for both HR-disable and full withdrawal. Independent review identified this edge. Active states/decoders now reserve both transitions while HR is enabled; decoded context endpoints obey the same limits. |
| `10-final-core.log` | PASS157 tests/15 suites after capacity/context corrections; policy-text finalization followed. |
| **`11-frozen-core.log`** | **PASS157 tests/15 suites**, including19 new unique owner tests, on the exact final manifest. |
| **`12-frozen-phone-release.log`** | **PASS**, `PadelStrokeLab`, Release, generic iOS Simulator. |
| **`13-frozen-watch-release.log`** | **PASS**, `PadelStrokeLab Watch App`, Release, generic watchOS Simulator. |

No failed run was hidden or automatically retried. Corrections changed the cause or added an independently required invariant; assertions were not weakened. Both final Release logs compile PadelCore for `arm64` and `x86_64`. These are simulator compilation receipts, not `arm64_32` execution, physical sensor, signed-device, UI or connectivity evidence. Each build reported only the existing App Intents extraction warning for targets without an AppIntents dependency; no Swift error/warning remained.

Final core command: `swift test --package-path Packages/PadelCore --scratch-path <O1>/SwiftBuild`. The final build commands use `xcodebuild -project PadelStrokeLab.xcodeproj -scheme <scheme> -configuration Release -destination 'generic/platform=<iOS Simulator|watchOS Simulator>' -derivedDataPath <O1>/<PhoneRelease|WatchRelease> CODE_SIGNING_ALLOWED=NO build`. `swift` and `xcodebuild` were invoked by their absolute paths inside the specified Xcode installation. The focused runs add the exact test/suite filters named in their log.

## What is implemented and tested

`OwnerPracticeIdentity` is one immutable explicitly attested owner/phone/Watch installation relationship with a fixed policy digest, revision-bound consent decisions, optional HR, withdrawal barrier, explicit re-consent and128 bounded retained decision IDs. It has no alias, guest, slot, enrollment-import or role-transfer API. State admission reserves room for HR-disable and subsequent withdrawal; capacity/overflow cannot silently retain an effective HR grant. Human attestation is a declaration, not proof of an Apple account or physical wearer. Checksums detect corruption, not adversarial forgery.

The exact policy text explicitly states local retention until deletion, refusal of new content at storage limits, no app-saved workout summary, independent system Health effects, optional current-practice HR, deliberate export and no unrelated study/cloud scope. Final policy SHA-256 is `7bb8c65e14078fa2cb1621449005448abd1e450848eadedaf3a6647e897769dd`. The independent Python policy/identity/context vectors are `final-independent-policy.txt`, `final-independent-identity-vector.json`, and `final-independent-context-vector.json`; the independent raw-metadata vector is `independent-raw-metadata-vector.json`. Literal/digest expectations reside in the new tests and passed against actual production codecs.

`OwnerRecordingContext.bind` accepts only canonical raw metadata, an active exact authority and compatible phone setup. It binds owner/device epochs, study/policy/consent/revision, practice/recording/clock identities, both setup generations, actual arm/wrist/crown and forehand/backhand intent. Both supported raw streams and the preserved manual logger protocol are required. A privately constructed `OwnerContextBinding` retains exact authority/raw bytes; any authority revision/consent change invalidates publication eligibility. Historical decode requires exact raw bytes and returns a context, never a publication binding or Start token.

The tests cover independent canonical bytes/digests; re-sealed semantic corruption; unsupported/duplicate/unknown fields; byte/revision/decision limits; wrong owner/phone/Watch; withdrawn/old/replayed/new-ID decisions; backward clocks; optional HR; both strokes/arms/crowns; setup/metadata/clock/protocol/channel mismatch; canonical raw-byte rejection; both generation changes; and unchanged raw bytes. These are pure values and codec tests. They do not prove persistence, no-follow locking, failed-ID nonreuse, actual consent capture, live Start linearization, runtime resource shutdown, Health acquisition, transfer, deletion or physical identity. Those belong to the remaining ordered packages.

## Handoff

Final working-tree source/evidence are ready for independent O1 verification. The reviewer performs no edits or builds. O2 may start only after exact O1 clearance and director handoff, consuming these interfaces without changing O1 production/tests. The source manifest and checkpoint preserve that boundary. Formal committed-HEAD G6 review, current hosted CI, physical G7 and user-authorized publication/merge remain open; this local metadata increment is not a completed first-build delivery.
