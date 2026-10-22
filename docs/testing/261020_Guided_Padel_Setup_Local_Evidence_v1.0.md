# Guided padel setup — local evidence v1.0

20 October 2026. Covers the owner-approved **Let’s Play** wizard, version 1.0/build 5. This is an owner-led recording prototype, not a validated clean-hit detector.

## Current source and scope

- Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`.
- Branch: `feature/guided-padel-setup`; base/HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Changes are uncommitted/unpublished.
- Current [57-file manifest](261020_Guided_Padel_Setup_Code_State.sha256): SHA-256 `208bc67b2f6017358ef13a559a6359a24f02bb7ab0159b8f9e45020a787b28b3`. All entries independently rechecked after final configuration amendment.
- Current Watch UI fixture SHA-256: `a380b6d0950690418205a82cdc23b9af1cf51f01300aff5191eec72639b7928c`. Production has not changed since the reviewed orientation correction. Watch model SHA-256 `d0aaab86c7922d939bea2e4a57394cf0939678735ef86cf459349a463d990420`; Watch unit fixture SHA-256 `c5cffd97d100b798a6a51f8d23d9df0cce94d358ec17a8bbce6623e9fffc6bbe`.
- Seven production/configuration files remain within the approved scope: new Watch preparation state/view; Watch model/landing; phone guide; build 5 settings; workflow manifest reference and the reviewed stacked-PR base filter. Capture engine, core schemas, protocols, storage, transport, export, permissions and historical data are unchanged.
- Xcode 27.0 (27A266a), Swift 6.4 and OS 27 SDKs. Every command selects `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Private evidence root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-GuidedSetup`. Command files, logs, results, exports, failed-source archives and diagnostic samples remain there. Do not publish personal raw recordings, device identifiers or provisioning material.

## Verification status

| Check | Actual result | Evidence and limits |
|---|---|---|
| Shared core | PASS: 108 tests, 10 suites | `root/02-core.command.txt/.log`; unchanged core source |
| Watch production-path model | PASS: 21 unique cases, 30 expanded executions | `author/05-unlocked-focused.log/.xcresult`, summary/tree; includes both orientation regressions; model/unit bytes unchanged since this pass |
| iPhone app-host and complete UI | PASS: 14 unique cases / 19 expanded executions; 0 failed/skipped | `root/12-phone-full.command.txt/.log/.xcresult`, `12-summary.json`, `12-tests.json`: 8 app-host cases (10 expanded), 6 UI cases (9 expanded); explicit nonparallel, enabled timeouts, 300-second default/maximum allowance |
| Complete Watch UI at final split source | PASS: 8 unique cases / 9 expanded executions; 0 failed/skipped | `root/14-watch-all-ui-split.command.txt/.log/.xcresult`, `14-summary.json`, `14-tests.json`, sequential attachment export; explicit nonparallel and 300-second default/maximum limits. Previous full run 10 remains preserved below |
| iPhone and Watch unsigned Release simulator builds | PASS | `root/05-phone-release.command.txt/.log`, `root/06-watch-release.command.txt/.log`; actual products checked version 1.0/build 5, minimum OS/SDK 27 |
| Signed generic physical build | PASS, build/signature only | `root/08-device-build5.command.txt/.log`, exit 0; `root/09-build5-signature-identity.json`. Phone and embedded Watch separately pass deep/strict signature checks, have unexpired development profiles, version 1.0/build 5 and minimum OS 27. No provisioning-update flag or installation |
| Manifest and scope | PASS: all 57 final entries match | Only the reviewed workflow trigger differs from runtime-verified source 1f93; no runtime/test bytes changed. Scoped diff check passed after documentation reconciliation; parent scope check verifies 23 changed files total, 7 production/configuration files, 562 changed production lines |
| Independent working-tree review | No verified source blocker | Astra Extra High reviewed orientation fix and both fixture corrections; formal committed-HEAD review remains open |
| Hosted CI / committed-HEAD review | NOT RUN for this package | Requires owner-approved commit/push/publication; baseline CI is not new-wizard CI |
| Physical replacement / recording | NOT PERFORMED for build 5 | Devices retain installed build 4; no physical motion, transfer/export or quality claim |

Unchanged per-file identity carries only the unaffected evidence listed above. A full affected-suite failure blocks readiness even when focused tests pass. No retries or higher time limits are used to conceal failures.

## Simulator visual evidence

Author focused run 06 passed the six-step guided flow in 214.476 seconds. Root inspected all six full-screen setup captures and the landing in `author/06-attachments/`; `manifest.json` maps names/files. Blue, yellow and white, native controls, progress and instructional text are consistent at the captured scroll positions. The screenshots do not show every control at once and cannot prove physical ergonomics. Root also inspected final phone run 12 uncropped full-screen normal home/guide and largest-text portrait/landscape home/guide captures in `root/12-phone-attachments/`. The native blue/yellow/white presentation and glass navigation are consistent. Large type requires scrolling and wraps headings, including the existing training-header word break; no claim of every control fitting onscreen or exhaustive physical accessibility testing follows.

Run 06 verified the honest simulator capture blocker and Cancel, then reached retained recordings. The Watch simulator cannot supply physical batched-motion evidence.

## Preserved failure and correction ledger

| Invocation | Actual failure/outcome | Diagnosis and bounded correction |
|---|---|---|
| Author initial model runs 01–03 | Initial model suite: 19 unique / 28 expanded passing cases. Run 01 emitted a captured mutable-variable warning; corrected before clean runs 02–03 | Earlier evidence is historical after the orientation correction; use run 05 for current model proof |
| Root full Watch UI 01 | Failed: 7 unique cases, 8 executions; 2 failed, 6 passing executions | Test tapped the already-selected Forehand in a native picker, leaving it open. Video and independently inspected `root/picker-failure-end.png` show the visible blue Close control. Fixture now acknowledges the suggested Forehand without reopening the picker, while exhaustive selection still exercises all 10 genuine changes. No production picker defect established; assertions/limits unchanged |
| Independent orientation review | Verified P2 source defect | `confirmOrientation()` could acknowledge values newly discovered by its own refresh. Corrected model checks the expected step, compares displayed/fresh settings, refuses a same-tap acknowledgement of changed settings, and requires a fresh tap. Out-of-order Review calls are rejected. Two additive production-path regressions pass in run 05 |
| Author corrective 04 | Interrupted exit 75 / TEST INTERRUPTED; finalized partial result: 0 passed, 3 failed entries | Mac lock was explicitly observed twice and a process sample showed simulator-install wait. App-host canceled; all-shot case failed at 302.919 seconds with invalid activation point; guided case failed at 94.605 seconds reaching retained refresh. Preserve `04-summary.json`, `04-tests.json`, cancellation verification, process sample and log. Only the verified owned Xcode process was gracefully interrupted. Do not attribute every failure solely to lock or treat this as a corrected-source pass |
| Author unlocked focused 05 | Exit 65: 23 unique, 22 passed/1 failed; 32 expanded, 31 passed/1 failed. Model 21/30 passed; all-shot UI passed 198.864 seconds; guided UI failed 105.543 seconds | Failure reproduced while unlocked, after all six screens, Start blocker and Cancel passed. Frames `05-retained-86s.png`/`100s.png` show short drags snapping back around the same large capability card. Fixture opts into existing larger held drag only while retained target is absent, then existing fine scan. Same 24 attempts, assertions, hittability and timeouts. Root and independent reviewer inspected evidence |
| Author focused 06 | PASS, one guided case, 214.476 seconds; no failures/skips/runtime warnings | Retained control reached at 214.11 seconds. Initial automation launch consumed roughly 136 seconds inside the unchanged 300-second bound. Full-screen captures exported; full-suite proof still required |
| Root full Watch UI 10 | Exit 65: 7 unique, 6 passed/1 failed; 8 expanded, 7 passed/1 failed; 0 skipped | Sole failure: combined all-shot/consent/relaunch case exceeded 300 seconds. Every other case passed. Summary/tree: `root/10-summary.json`, `10-tests.json`; full log/result retained. Xcode restarted the runner to continue remaining cases after timeout; it did not retry the failed case |
| Simulator preview preflight 15 | Container lookup failed; preview script exited 1 | Read-only diagnosis `root/15-preview-readonly-diagnosis.json` reports CoreSimulator error 405 / command exit 149: both standard simulators were Shutdown after the test run. Explicitly booted the verified OS27 pair, installed the current tested simulator products and launched without test arguments. `root/16-simulator-preview.log` and receipt verify both version 1.0/build 5 and executable hashes matching tested products. No physical-device action or failed-test retry |
| Initial result export | Concurrent result reads hit lazy `database.sqlite3` cache conflict | `root/01-attachment-export-failure.txt` retained; summary and sequential export succeeded. Tool diagnostic, not an app/test pass. Subsequent result reads/exports are sequential |

### Run 10 diagnosis and assertion-preserving split

Astra's read-only diagnostic distinguishes actual system quiescence (0.229814 seconds) from the initial installation/launch delay (108.86 seconds before automation, including 71.4 seconds awaiting observed app PID). The underlying launch latency remains unexplained. The second launch was normal: terminate 276.13 seconds, launch 277.22, automation 277.65, idle 279.59, landing 281.30. All ten choices, Other explanation and consent invalidation completed before repeated fresh setup crossed the 300-second allowance. Do not label this a production hang or claim the latency is fixed.

After run 10 ended, the test contract approved separating independent behaviors. Seven inserted test lines keep exhaustive ten-choice changes/equalities/Other explanation in one case. A separate fresh setup explicitly chooses Other, then runs the untouched final-confirmation=1, Back→Serve, step 5, final-confirmation=0, terminate/relaunch, fresh setup and persisted-Serve assertions. Independent Astra review verified all 32 assertion/failure lines and wait/24-attempt lines remain byte-identical and ordered. Limits remain 300 seconds. No production change. Final full Watch UI run 14 passed all 8 unique cases / 9 expanded executions after this split. Exhaustive selection passed 186.529 seconds; the independent consent/persistence case also passed within the unchanged limit. The actual earlier failure remains retained.

### Exact historical identities

- Initial 57-file source: `99820a5af30174a1a2ac5288dc50fbf2660745bdb7f9437d88677d79690604a5`; retained `root/01-source-manifest.sha256`, `01-failed-ui-source.zip`.
- Orientation/picker correction: `d8aaf11643b1e741e57a5c353b4960fb048ea9f1b08664f7c72529be18404b78`; run 05 failed fixture/manifest retained under `author/05-failed-*`.
- Retained-list held-drag fixture: `e4924f4f6cf34ced253c56a92559e40d3fe483e3e427d0379fc8907ea3439646`; failed run 10 source/manifest retained under `author/root10-failed-*`.
- Runtime-verified split fixture: `1f93fc12aa93250fdc676ef02cf3f3129ea4b0d1591f72231faf16f42bb6abbf`. Only Watch UI fixture differs from the preceding identity. Phone run 12 and Watch run 14 both pass at this state.
- Final CI-trigger amendment: `208bc67b2f6017358ef13a559a6359a24f02bb7ab0159b8f9e45020a787b28b3`. Only workflow hash changes from the runtime-verified split state; all runtime/test source remains identical.
- The prior full local narrative is preserved as `root/13-evidence-before-reconcile.md`; commands/results/source archives remain unchanged.

## Final CI trigger amendment

The planned stacked draft PR targets `feature/watch-recording-storage`. Existing `pull_request.branches` allowed only `main` and `chore/project-governance`, so it would not request normal PR checks for this base. Astra Extra High independently reviewed a minimal amendment; architecture/test contract scope was explicitly updated before editing, after both runtime suites ended.

Only one workflow line adds literal `feature/watch-recording-storage`. Existing triggers, `workflow_dispatch`, permissions, checkout HEAD selection, runner, build/test commands and timeouts remain unchanged. Ruby Psych parses the YAML and verifies the exact three-base list plus dispatch. The author archived `final-runtime-1f93-Code-State.sha256` and `final-runtime-1f93-foundation.yml`; parent independently compared manifests and verified the workflow is the sole changed entry. All 57 final hashes match. Workflow SHA-256 is `91cbed6919112f5431b18ad24d195b7089d626dc96cf30ba2a9d2c2e31757451`.

Checks are retained in `author/final-ci-trigger-verification.json` and `final-ci-trigger-yaml-parse.json`. Unchanged runtime/test bytes retain their completed evidence; no runtime rerun is justified by this trigger-only change. Hosted CI behavior remains unproven until an actual run on the approved pushed HEAD.

## Live simulator preview status

Both standard simulator apps are queried as version 1.0/build 5, executable-matched to the tested build products and launched without test arguments (`root/16-simulator-preview-receipt.json`). Native foregrounding is not yet verified: computer-use inventory explicitly reports the Mac locked again and automatic unlock unavailable. The owner has been asked to unlock it. This does not negate the completed passing result bundles or genuine exported screenshots. No native-window foreground visibility is inferred from successful CLI launch. Direct simulator captures were subsequently collected as `root/18-watch-live-preview.png` and `18-phone-live-preview.png`; parent inspected both current normal-size landing screens. This provides genuine current screenshot review while native foregrounding awaits unlock.

## Physical limits and next gates

The [build 4 checkpoint](261020_Build4_Installation_Checkpoint_v1.0.md) separately records baseline phone/Watch installation and owner-confirmed launches. It does not establish physical recording. Build 5 has not replaced those apps.

The independently checked [guided first-set runbook](261020_Guided_Setup_First_Set_Runbook_v1.0.md) begins with mandatory arm/placement/orientation/fit/shot/final confirmation every new set, followed by one controlled air swing and verified phone transfer/export before court contact. Record applicable owner installation authorization; displaying simulator UI or publication approval alone is not installation authorization. Pause/Resume belongs to the same set. Fit/physical placement are self-confirmations, not sensor detections.

Complete current local automation and visual/source reconciliation before requesting permission to commit/push/open a stacked draft PR. Exact-HEAD hosted CI, formal independent review, applicable installation authorization and observed physical dry run remain open. No merge/release readiness claim is made.

## Concrete publication package awaiting owner approval

Proposed title/commit subject: **Require guided Watch setup before every training set**. Head branch `feature/guided-padel-setup`; proposed stacked draft-PR base `feature/watch-recording-storage`, whose remote HEAD remains `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Existing PR2 remains draft/open into `chore/project-governance`; main and foundation remotes are unchanged. No wizard remote branch exists. Parent fresh preflight is retained in `root/17-remote-preflight.json`.

Scope: the seven approved production/configuration files, three existing test files and thirteen documentation/evidence/manifest files (23 changed files total). Parent verified 562 changed production lines, no unexpected production path, all57 source hashes matching and unchanged HEAD/base in `root/17-final-scope-source-check.json`. No secrets, provisioning material or personal raw captures are added.

Proposed description: Every new recording set now begins with a six-step Watch wizard for current racket hand, actual placement, configured wrist/crown, comfortable fit, intended shot and fresh final confirmation. Saved preferences do not grant recording authorization; preparation preserves active capture and retained recovery. Phone guidance and shared theme match. The branch also enables CI for its stacked PR base.

Validation: core108, Watch model21 unique/30 expanded, phone14 unique/19 expanded, WatchUI8 unique/9 expanded, both OS27 Release builds and signed generic build5/signature checks pass. Failures remain recorded. Runtime tests passed at1f93; final208bc differs only in the reviewed trigger filter. Fresh exact-HEAD hosted CI and independent committed-source review remain required after publication. Physical build5 replacement requires applicable owner authorization and device preflight; observed dry-run/transfer/export remain required before court contacts. No merge or release is authorized.
