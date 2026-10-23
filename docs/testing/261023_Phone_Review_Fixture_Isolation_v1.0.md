# Phone review fixture isolation

23 October2026. Branch `feature/guided-padel-setup`, amendment base `e43eb7fb25dc2bcdafca7ab5ca060d3926a96d64`. Three-line test-only correction; production callbacks, locks and serialized repository behavior are unchanged.

## Retained failure and cause

[CI39880508648](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39880508648) passed all27 phone UI executions with zero failures. Its74-method app-host suite then failed one included-mode execution of `manualLabelHistoryCreatesNewImmutableRevisionsWithoutChangingEvidence`. The raw log identifies the test wrapper; the result bundle identifies the actual throw at line194, the fixture's independent `store.open`, not model save or export. The absent/excluded executions passed. Full run and final foundation failed, correctly.

Receipt delivery emits publication/onChange before invoking completion. Automatic library refresh therefore schedules a repository read while the test directly opens the same store outside that repository's actor. Included/absent telemetry requires an exclusive nonblocking lease; a concurrent reader correctly receives `unavailable`. Normal model list/open/save operations share the serialized repository. The test created an additional independent owner. This explains the failure location; it is not a blanket claim that all production concurrency is proven safe.

## Ratified amendment

In this test alone, set `f.connection.onChange = nil` before receipt delivery, matching the existing independent-reader fixture pattern in two neighboring tests. Two comments explain why. Keep all three modes, actual receipt handling, independent original/prior-revision reads, explicit model open/save/export calls and every assertion. Do not change locks, waits, retries, production observers or hardware defaults. Unchanged other tests and full UI coverage retain normal observer behavior. The existing Core exclusive-lock regression remains intact.

Independent plan and saved-diff review both clear this exact three-line change in `PadelStrokeLabTests/OwnerPracticeReviewTests.swift`. It is the sixth source/test/config path in the combined deadline-correction candidate and does not invalidate the unchanged production inputs of signed build7.

## Actual local proof

Explicit Xcode27.0 and the existing owned disposable iPhone15Pro simulator on iOS27.0/build24A5408d were used. No reset, uninstall, new simulator or test retry occurred. The isolated runner retains hardware-unavailable fixture arguments.

- Debug test-product build: passed.
- Focused review suite:12 methods/18 expanded executions,17.142seconds, zero failures/skips.
- Full Phone app-host suite:74 methods/125 expanded executions,34.482seconds, zero failures/skips; all three label-history variants pass.

Private `O13-PhoneFixture` retains command logs, result bundles, summaries and runner hashes. Earlier full CI UI results are preserved observations for that source, not a new local UI pass. Full phone/Watch/Core CI and final foundation must pass at the new exact committed HEAD before installation clearance. See [deadline correction](261023_Practice_Deadline_Correction_v1.0.md) for combined source identity and build7 proof. Live outcomes attach to [PR#3](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/3).
