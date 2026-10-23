# O8b complete-practice transfer — local verification

22 October 2026. **Accepted locally as O9 prerequisite. Physical testing NOT READY.** Branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Intentional unpublished working tree; no commit/push/PR/merge/install. Astra Extra High authored production, Astra High authored bounded harness corrections, non-Astra Sol directed verification and a separate Sol reviewer independently accepted source/tests/actual final evidence.

## Frozen candidate

Private evidence root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/PhysicalReadiness1`.

Source20: 105 inputs, 637 added-plus-removed production lines / 1,700 cap. Manifest `O8b-20-source.sha256`: `d43a8af222ed45a0b2161ffd781f690d09051136afe7d7ca5fd2823e50b20926`. Archive `O8b-20-source.tar`: `09159fd0a98bb8711f0145449e76f77886624b4a1471dd5b66639b2f815c1af1`. [Repository manifest](261022_Owner_First_O8b_Source_v1.0.sha256).

Only six production paths differ from accepted O8a17: Core RecordingConnectivity (389 lines); phone RecordingLibraryModel (88), PracticeSetupModel (53); Watch WatchRecordingServices (68), WatchRecorderModel (4), OwnerCaptureCoordinator (35). All other predecessor/configuration inputs remain exact. Three new transfer test files define 18 methods/26 expanded executions. Source20 matches corrected tests08.

## Actual verification

All commands explicitly selected Xcode27.0/27A266a via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; OS27 Simulator SDKs. Every final assessment reports all 105 source hashes unchanged.

| Stage | Actual result | Seconds |
| --- | --- | ---: |
| Core09 focused | PASS 6 methods / 10 executions, zero issues/skips | 21.584 |
| App build10 | PASS build-for-testing | 24.662 |
| Watch13 focused | PASS 5 / 8, zero failures/skips | 37.198 |
| Phone build15 | PASS proper phone-scheme build-for-testing | 28.214 |
| Phone17 focused | PASS 7 / 8, zero failures/skips | 17.481 |
| Core19 full, explicit --no-parallel | PASS 373 / 668, zero issues/skips | 292.476 |
| Watch22 full eligible app-host | PASS 105 / 172, zero failures/skips | 32.931 |
| Phone24 full eligible app-host | PASS 56 / 101, zero failures/skips | 20.310 |
| Phone26 Simulator Release | PASS, actual BUILD SUCCEEDED | 203.757 |
| Watch27 Simulator Release | PASS, actual BUILD SUCCEEDED | 203.757 |

Core uses actual SwiftTesting XML, excluding its aggregate test-run row and counting parameter expansions. App-host counts come from actual xcresult summaries. Release result JSONs independently record the same elapsed value after concurrent cold builds; both logs confirm success. Exact commands, logs, result JSONs, XML, xcresults and assessment reports are retained under the stage prefixes above.

Phone/Watch host runs used their proper scheme-generated runners with early isolated fixture identities. Preflight21/23 checked the runner, test plan, bundle/host SDK, available OS27 destination and fixture before full launches. The full hosts exclude only their original default-path cases: phone `defaultAppContainerCanWriteInspectAndAnnotate()` and Watch `productionContainerPathsAcceptActualAppStorage()`. These unchanged bodies and final UI/launch/performance tests remain for O11 on newly created disposable paired simulators.

Guards11/18/25/28 confirm **no additional changes since incident46 ONLY**. Both reserved original containers relocated; original phone differences remain13 and Watch0. This is not proof original defaults were unchanged. Reserved pair was not reset/restored/erased.

## Preserved failures and corrections

- Missing-interface02 Core exit1/17.114s and03 app exit65/16.429s precede production and reference planned missing transfer types.
- Source04 Core05 compiled but failed all6/10 before transport with ENOTDIR. Diagnostic07 showed Foundation retained /var while C realpath returned /private/var. Strict production no-follow checks were correct. Narrow tests08 adopted established trusted-root realpath handling.
- App06 exited65/22.763s on three throwing Watch macro expressions. Tests08 hoisted only those calls outside macros. Independent review accepted both narrow harness amendments; assertions/counts and production unchanged.
- Phone14 exited70/61.756s before tests because the Watch-scheme runner cannot select the phone destination. Failure retained; proper phone build15/runner16 produced focused17. No unchanged-condition retry or timeout/assertion weakening.

## Acceptance and remaining gates

Separate Sol review accepted exact final manifest/archive/current files, actual reports/XML/logs and scope as O9 prerequisite. [Source review](../reviews/261022_Owner_First_O8b_Local_Review_v1.0.md); [test review](../reviews/261022_Owner_First_O8b_Tests_Review_v1.0.md).

O9 complete deletion, O10 phone results and O11 final integration/default-path/UI/CI remain. Local acceptance does not establish formal committed-HEAD G6, signing, publication, merge approval or physical behaviour. Real-device installation and tests require root's later user gate.
