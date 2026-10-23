# Relevant setup guidance verification v1.0

23 October 2026, Asia/Dubai. Affected local checks pass; exact-commit review/CI
remain distinct. This is not physical-device clearance.
Branch `feature/guided-padel-setup`, amendment baseline
`e38f84fa8aa8e65426b1e52317c2a40ea13c4c20`.
[Owner-approved contract](../design/261023_Playing_Arm_Setup_Simplification_v1.1.md).

## Change and identity

Inherited Astra implementation agent changed only `PracticeSetupView.swift` and
`OwnerPracticeSetupUITests.swift`. Root performs non-Astra verification/docs;
independent read-only review follows the final commit. Exact inherited reasoning
settings are not independently exposed.

The matching-wrist branch retains its short placement confirmation and hides
orientation/fit/repeated per-set text. The different-wrist branch retains existing
move/configuration/fit instructions. Explicit answers, general local-Start notice,
preparation gating and all Watch checks remain. No model/Watch/Core/Health/capture/
transport/storage/project/build/workflow change.

Frozen [v1.2 manifest](261023_Playing_Arm_Setup_Code_State_v1.2.sha256), 115 inputs,
SHA-256 `6c61f2ca2135a5f41b59cd0e1658fa2e5845751b716a7cb66468a9aa8067d5d7`.
Phone view SHA-256
`4c2d02746f47496d7356fbde0f8cb03451465b993fb2c9f91d8003a4e6ca5c96`;
UI tests SHA-256
`cba40e86435621da89054f27da28288f1a1ed0788640416500d0d52209866538`.
Earlier frozen snapshots remain immutable historical evidence.

## Test contract and retained execution

Tests changed before production. The private tests-first patch is retained under
`PhysicalReadiness1/O15-MatchingWristGuidance/01-tests-first.patch`, SHA-256
`f87e05e50b0a293b2b52320d16980e92c3fd3d9453265d44fdb211b3a5798f0f`.

The four-pairing method now asserts detailed instructions are absent for both
matching cases and present with unchanged content for both move cases. Existing
placement/reset/preparation assertions remain; the general local-Start notice
must remain. Largest-text navigation explicitly selects a move case after menu
coverage, retaining detailed-text reachability and all five native audit categories.
Because those test paths changed, earlier native evidence is not reused as proof
for this increment.

Xcode 27.0 (27A266a), iOS/watchOS 27 SDKs. Tests use the isolated disposable iPhone
15 Pro iOS 27 simulator, separate from the user-visible paired simulator. The
existing runner's offline fixture arguments are unchanged; its copy stays in
Products to preserve `__TESTROOT__`. Private current evidence:
`PhysicalReadiness1/O15-RelevantSetup`.

| Check | Result | Evidence |
| --- | --- | --- |
| Affected Debug test build | PASS | `02-debug-build.log`; existing O14 DerivedData reused for incremental compilation. |
| Four pairings and two largest-text methods | PASS: 3/3 methods, zero failures/skips | `04-focused.xcresult`, `04-focused-test.log`, `05-focused-summary.json`; one invocation, no retries, default/maximum 300 seconds per method; suite513.965s. |
| Affected Release build | PASS | `06-release-build.log`; phone and embedded Watch dependency, signing disabled. This is not signing/device evidence. |
| Independent exact-commit review / full CI | Pending publication | Baseline CI is not clearance for this changed source. |

During this amendment, the preceding-head CI run
[39934374336](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39934374336)
passed Core but its Watch job failed launching the UI test runner:
`Failed to find service com.apple.CoreSimulator.host_support` (CoreSimulator
SimError 405, underlying no-such-process). The required Watch UI method did not
obtain valid execution evidence. The captured job log is retained privately as
`00-baseline-ci-watch.log`; the underlying service-loss cause remains unknown.
This is a failed required gate, not an application assertion or a cleared check.
No automatic rerun or speculative Watch/workflow change is part of this UI scope.
The next changed commit requires a fresh full CI run and review of any failure.

All 115 current input hashes verify; exactly the phone view and existing UI test
file differ from the amendment baseline. The frozen tests-first patch hash and
scoped `git diff --check` also verify. No capture/model/Watch or workflow path
changed. Both native accessibility methods ran again on these frozen inputs;
earlier native results are not being used to clear changed test paths.

## Preview and remaining gates

The user-visible phone simulator was terminated, updated from the newly built
Debug app and launched successfully with the existing explicitly synthetic review
fixture. Its two example reviews remain synthetic, not captured sensor evidence.
The Watch simulator and physical devices were not replaced.

No physical motion/Health/background/transport observation, merge, release or
court-readiness claim follows from this UI amendment. Finish affected checks,
publish source/evidence and record exact-commit CI/review outcomes on PR #3 before
gate clearance. The manual simulator walkthrough may then resume.
