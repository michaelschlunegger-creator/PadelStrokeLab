# Owner-first O4q — blocker correction evidence v1.1

21 October 2026. Astra Extra High authored the bounded production/test changes. Root used non-Astra verification/documentation; independent source and evidence review uses GPT-6.1 Sol High. This is a local working-tree checkpoint, not committed-HEAD G6, merge clearance or physical readiness.

All required **local correction checks pass** on the frozen source below. The independent v1.1 report and director acceptance are recorded separately. Original v1.0 source/evidence/review and every failed diagnostic remain preserved.

## Identity and scope

- Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, no upstream. Live main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; existing draft PRs1/2 unchanged. Current work is unpublished.
- Xcode27.0 `(27A266a)`, both27 SDKs; every build/test command sets `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Global selection was not changed. Native Xcode access and reserved booted OS27 simulator pair were verified.
- Compared with accepted O4a, exactly four inputs changed: `PracticeSetupChannel.swift` and its tests, `RecordingLocalCopiesTests.swift`, and `OwnerPreparationTransportTests.swift`, under `Packages/PadelCore`. Other78 inputs are exact.
- Cumulative production delta: **+118/−11 =129 changed lines**, within200. The staged A–E contracts bound identity correction, separate measured diagnostics and test-worker corrections. No app adoption, protocol expansion, timeout increase or assertion weakening was introduced.

## Correction and preserved failures

The channel now rejects local End request identifiers aliased by exact-practice retirement intent or verified entries. Validation happens before candidate writes and replay; rejected operations preserve healthy owner state, journal, local End and existing commands. Direct request, obsolete replacement, reverse latch order and forged/reopened-state regressions cover the bypass. Distinct-ID retry and retirement recovery remain covered.

Red01 reproduced17 issues in five regression functions before the production fix; green02 passes7 tests/1 suite. The original v1.0 full run failed260/20 at an existing10s receipt barrier. Its exact cause was not traced retrospectively.

Instrumented full03 reproduced a receipt failure: importer scheduling took19.298s, whereas actual import-to-receipt work took7.664ms. The test now runs real import/delete work on two explicit retained Foundation.Thread workers with user-initiated QoS set before start. Its10s waits, real contention, ordering and no-resurrection assertions remain intact.

Corrected full04 passed the receipt/identity cases but exposed the separate cancellation fixture failure. Diagnostic full05 measured commit fallback at5010.619ms, before cancellation submission5010.666ms; the100ms timer was timely. This did not establish a production lock bypass. The existing transport test now awaits real synchronous commit on an explicit worker, uses a separate cancellation worker/start barrier, and requires successful explicit commit release. One continuation resumes from the real commit result. Existing5s/100ms budgets, generic timer behavior, response/drain/order assertions and cleanup remain.

Full06 passes267/20. Its trace proves cancellation started5.450ms while commit was held; the negative probe returned false117.254ms, main released117.260ms, commit exited117.817ms, and cancellation returned120.812ms. The receipt path also exercised real contention and explicit release. These are source-dependent corrected runs, not blind retries.

## Fresh local verification

Private root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/`; paths below are relative to it. Exact commands, combined logs, exit codes and durations are retained in `O4qFix1/*.command.json`, `.log` and `.result.json`.

| Run | Result |
| --- | --- |
| `02-identity-green` | PASS7/1; test0.302s, process9.441s |
| `06-corrected-transport-full` | PASS267/20; test101.238s, process109.243s, exit0 |
| `07-app-host-build` | Fresh Debug build-for-testing PASS;133.223s |
| `08-app-host-enumeration` | PASS; exact29 enabled functions, all16 bootstrap functions, only previously ratified default-write test excluded |
| `09-app-host-runtime` | PASS29/4; test2.240s, process9.732s, exit0; actual result IDs exactly match enumeration |
| `07-container-before`, `09-container-after` | PASS; protected28 phone/88 Watch entries exact |
| `10-phone-release` | Generic iOS Simulator Release PASS;111.040s |
| `11-watch-release` | Generic watchOS Simulator Release PASS;103.929s |
| `12-diff-check` | PASS |

Phone test destination: `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`; protected Watch: `91757361-AEA2-41D8-9C4F-6DE5FF6365DA`. Runtime uses the generated runner copied inside its Build/Products directory, the existing `--motion-statistics-fixture=unavailable` isolated host and disabled parallel testing. Only `PadelStrokeLabTests` runs; exactly `RecordingLibraryTests/defaultAppContainerCanWriteInspectAndAnnotate()` is excluded as ratified in O4a. `09-result-tests.log` contains the actual result tree; selection comparison is recorded separately. No UI tests were needed for this non-UI correction.

The guard compares protected Documents, Application Support and app preferences entry sets, types, modes, inode/mtime and regular-file size/hash on both simulators. All match. Simulator installation migrated the phone container path; Watch path did not change. Path migration is recorded separately, not hidden as unchanged container identity. No erase, uninstall, timestamp restoration or default-data repair occurred. This guard does not cover every transient write or all filesystem metadata.

Builds report zero compiler errors. App-host build has four existing App Intents metadata-extraction warnings; each Release build has two of the same warning. The app has no AppIntents.framework dependency. Other framework diagnostics remain in raw logs.

The first evidence-seal script failed because its regex required plural “suites” while green02 reports “1 suite”. The original script and failure record remain; corrected parser accepts both forms and validates identical existing output without rewriting it. No product/test change or test/build rerun followed that reporting correction.

## Sealed source and evidence

| Artifact | SHA-256 |
| --- | --- |
| [Public source82](261021_Owner_First_O4q_Source_v1.1.sha256), exact copy of `O4qFix1/06-corrected-transport-source.sha256` | `11501ad6d8402ff5c9e05af9c2413e31582591cc17784d65a3ddb97a8e96f17b` |
| `Checkpoints/04q-fixE-source.tar` | `27cc5e5787be7ffb9048fc2f26ea3d982256059bbf1119b2c00e30156ef45514` |
| `O4qFix1/evidence-v1.1.sha256`,266 entries | `8aad2dd6aeac4a7d0086171a1fb886a55ade6a3c085a9cac24e73014b1c39b99` |
| `O4qFix1/12-validation-summary.json` | `5f57f321bfaee77b3b4dc3c480e2da438ee57b6c76a9ca64c3fe488e90081bfb` |

The82 current inputs,82 archived inputs and embedded manifest match;78 protected O4a inputs remain exact. The evidence index includes failed attempts, diagnostics, guard/selection/source validations, commands/logs/results, result-bundle files, scripts and runners. Historical artifacts are not relabelled as passes.

## Limits and next gate

The [independent v1.1 review](../reviews/261021_Owner_First_O4q_Review_v1.1.md) must challenge these exact inputs and evidence before director acceptance. O4b phone adoption remains unimplemented by this correction. Watch admission, HR/recovery, complete practice delivery/export/deletion, results and integrated tests still need completion. No new code was published or installed physically. Clean CI, committed-HEAD independent G6 and physical G7 remain outstanding; no merge or on-court readiness claim follows from these simulator checks.
