# Core fixture portability — verification

23 October 2026. Branch `feature/guided-padel-setup`, amendment base `e5d1ce38c3ee8ca7895dcee7989b76ae8a2573a1`. Only test-fixture locations and the aggregate CI job budget change. App/Core production, assertions, per-test deadlines and concurrency remain unchanged.

## Preserved CI failure and root cause

[CI39840482415](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39840482415) failed its full 388-method Core run with 164 issues. Every issue is a permission error from the same two fixed developer-home fixture roots in `PracticeSetupChannelTests.swift` and `OwnerPreparationTransportTests.swift`. The remote runner cannot write into that unrelated user's home. Later app checks were skipped; this run is not passing evidence.

The bounded correction changes eight lines across those two test files. Each fixture resolves the OS temporary directory with the existing `realpath`/`free` pattern and appends its own suite prefix and fresh UUID. Cleanup remains restricted to that constructed fixture root. All behavioral assertions, explicit concurrency and limits are unchanged. Independent Sol source review clears this test-location-only amendment. A complete search of Swift/project/scheme/workflow inputs finds no remaining fixed user-home paths.

## Verification and source identity

`Privacy-CI-01-core-focused`: both actual affected suite methods pass, zero failures/skips, 0.382 seconds of test execution. The full serialized Core run `Privacy-CI-02-core-full` passes all 388 methods/696 expanded executions, zero failures/skips, 710.176 seconds of test execution. Commands explicitly select Xcode27 and pass `--no-parallel`; no failed test run is automatically retried unchanged.

`Privacy-Final-Source2` freezes all 115 inputs; manifest SHA256 `a759825ef2b5ca080a887b6e31c0bba0490917ba70a2f87fe8e0941bb7fcaa49`. The only differences from Source1 are these two Core test helpers. All app production, Core production and phone/Watch test inputs remain identical. Full Watch130/206, phone host74/125, four UI passes, both Release builds and signed products/profiles retain their exact app-input evidence. See [privacy correction verification](261022_Privacy_Readiness_Corrections_Verification_v1.0.md).

New exact-head CI and final committed review remain required. No installation, physical sensor pass, merge or distribution release is established by this record. PR#3 carries subsequent live evidence for the tested commit without changing source to record device outcomes.

## Current CI budget and source

The complete Core run took 11.84 minutes; the previously measured full phone suite took 39.06 minutes and Watch5.74 minutes. Together with the observed four-minute CI simulator preparation and required builds, the60-minute aggregate job cap is insufficient. Independent review approves90 minutes for the aggregate job only. The Core step remains15 minutes and every per-test deadline/assertion remains unchanged. This budgets the existing required tests; it does not retry or waive failures.

Source3 changes only that workflow budget relative to Source2; all Core/app test and production inputs are identical to their passing evidence. Current115-input manifest SHA256 `58fc81d73add11d9373ade24a9dba344e57330f9d8afc834c8999c83cadcca93`. Actual Core XML is `Privacy-CI-02-core-full-swift-testing.xml`; the retained log independently contains388 passing method rows/696 expanded executions and zero issue rows. New exact-head CI remains pending publication.
