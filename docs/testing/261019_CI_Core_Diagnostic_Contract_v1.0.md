# CI shared-core liveness diagnostics — v1.0

## Superseding measured correction — 19 October2026

Baseline8075991 run39255888191/job118070941571 has now completed FAILURE, with105 tests and three issues in one production-writer lease test. Earlier IN_PROGRESS/HTTP availability observations below are historical. Actual state values were unavailable; the uncontrolled real-clock/missing-stream fixture is the demonstrated defect, with watchdog interruption the qualified explanation. See [bounded correction contract](261019_Deterministic_Production_Lease_Test_Contract_v1.0.md).

Astra Extra High approved revising the not-yet-published shared-core step bound from10 to15 minutes before the workflow edit. The step ran13:02:54.785755–13:12:43.464577 UTC,588.679 seconds; compilation reported538.15 seconds. Ten minutes leaves11.321 seconds headroom. Fifteen remains a bounded diagnostic deadline. Preserve the45-minute job limit, exact Swift command/scratch directory, pipefail/tee and unconditional artifact upload; no retry, skip or continue-on-error. Baseline failure evidence upload succeeded: artifact12188571201, `foundation-39255888191-1`, SHA256 `b92fafa396f9daee6340160dd79fd04ffab3c62fe1d523c5d6aec148677d9bcf`. This supersedes the current/root-cause-unknown and unmeasured-cold-duration wording below without erasing its historical account.

19 October2026. Defined before workflow changes, in the owner-authorized complete logger verification cycle. Astra Extra High returned PROCEED for the10-minute diagnostic bound after inspecting workflow/package; no application behavior change. The existing training package parent scope allowed a manifest reference update; this adds a separately bounded CI diagnostic timeout only after review.

## Observed evidence

- Old exact-HEAD8379aaa run39245546273/job118036462483 ended CANCELLED after the45-minute job deadline; backend annotation confirms timeout. Shared metadata was active during observed progress. No successful result follows.
- New baseline exact-HEAD8075991 run39255888191/job118070941571 remains IN_PROGRESS; fresh GitHub page navigation showed Verify shared metadata active roughly16 minutes after run creation. This does not prove the cause or that any specific test is responsible.
- Code-review job-log access returnedHTTP502. Purpose-built GitHub connector job-log reads for old/new jobs returned404 BlobNotFound; oldrun artifacts list was empty. Log availability failures are distinct from test failures.
- Local exact correction source passed105 core tests in9 suites, with the actual test phase2.174 seconds after compilation. This does not establish hosted behavior.

## Approved bounded change

Only `.github/workflows/foundation.yml`, in addition to the already authorized new source-manifest reference. Add a10-minute timeout to Verify shared metadata, leaving its actual Swift test command, scratch directory, pipefail/tee, suite/assertions and job45-minute limit unchanged. Keep always-upload evidence. This is a failing diagnostic bound, not a skip, retry, test relaxation or inferred root-cause fix. A step deadline should leave time for the existing artifact-upload step instead of losing the whole job at45 minutes. No production, dependency, platform, runner, signing or permission change.

## Verification and limits

Before final freeze: inspect exact YAML diff, parse YAML and assert only intended core step has the added timeout. Include workflow in the new complete-training source manifest. Subsequent exact-HEAD CI is authoritative: preserve a bounded failure and its logs if it occurs; inspect evidence and correct only a demonstrated cause. Do not automatically rerun to obtain green. If normal compilation itself exceeds the diagnostic bound, retain that result and revise only with evidence. No physical install or merge-ready claim while CI remains open.


## Astra review conditions

The review confirmed PadelCore has no external package dependencies and10 minutes is reasonable for failing diagnostics; hosted cold duration is unmeasured. Existing live run39255888191 is unaffected. Keep the exact suite/command/pipefail/tee/failure behavior and45-minute job cap, with no retries/skips/continue-on-error. Confirm actual artifact retention after a bounded failure; runner loss can still prevent upload. Inspect core-tests.log before further diagnostics, and do not speculate about buffering/test behavior. If evidence contains no useful progress, a later separately bounded failure diagnostic may record process names/states/elapsed times. Current root cause remains UNKNOWN. No files/tests/builds were changed by the reviewer.
