# O6 telemetry and recovery — local verification

22 October 2026. Astra Extra High authored foundational source/tests. Root executed verification; independent Sol reviewed source and results without editing files. Branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. This is unpublished working-tree evidence, not current committed-HEAD CI or physical evidence.

## Scope and source

Three new Core files implement validated owner-practice telemetry, bounded checked storage and pure recovery calculations. They do not acquire native HR, operate the Watch practice lifecycle, deliver whole practices or display new phone results. Existing raw-v1 formats and capture authority remain unchanged.

Frozen15 contains94inputs. Manifest SHA-256 `c05e58db4eb1d50871f278f58059db768d7f494f2804446854d1a3a8e9e07173`; archive `68c2b99e3979fda0c541772059732c583095d57dec434a1f4a55f41e4d14db68`. [Source manifest](261022_Owner_First_O6_Source_v1.0.sha256). Root and reviewer independently verified all input bytes; all91 other inputs/tests13 stayed unchanged during the final41-line correction. Production totals1,220/1,800 lines: telemetry740, store309, recovery171.

The new code preserves distinct raw clock domains/calibrations, immutable consent/query segments, native sample identity with earliest arrival, bounded canonical conflicting versions, aggregate native rejection counts, durable source-deletion invalidation, exact observation windows and signed drops. A known next set or consent closure cannot leave recovery pending. A narrowly interrupted backwards-clock ending preserves actual terminal timestamps and native payload while making ambiguous readings ineligible. Publication verifies the requested bytes and open-stage inode before adopting a component.

## Executed evidence

Private evidence root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/PhysicalReadiness1/`. Each run retains exact command, log, result and available XML/xcresult. All commands explicitly used Xcode27.0/27A266a with iOS/watchOS27 SDKs through `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Run | Result |
| --- | --- |
| O6-14 meaningful regression red | Exit1/17.971s;79methods/148expanded executions,11issues in6runs. Exact remaining defects: known-closure pending, allowed backwards terminal rejected, both real stage tamper modes falsely successful. Other142executions pass. |
| O6-16 focused green | Exit0/20.198s; exact same79methods/148executions allpass; no failures/errors/skips. |
| O6-17 default full regression | FAILED exit1/97.187s;346methods/613executions, sixissues in one existing connection test. All O6 cases pass. Retained. |
| O6-18 explicit serialized full regression | Exit0/267.891s; exact same346methods/613executions,23suites, no failures/errors/skips. |
| O6-19/20 build-for-testing | Watch42.023s and phone38.215s, bothPASS. |
| O6-24/25 host enumeration | PASS; exact48Watch and49phone enabled methods match prior baselines, no missing/extra IDs. |
| O6-30 Watch host | Exit0/15.456s;48exact methods/67expanded executions allPASS. |
| O6-31 phone host | Exit0/12.680s;49exact methods/93expanded executions allPASS. |
| O6-33/34 Release | Both unsigned generic iOS/watchOS Simulator Release buildsPASS/84.585s; reviewer independently verified distinct commands, destinations and logs. |
| O6-23/26/29/32/35 data guards | PASS; final35/0.877s. No additional default-container changes since retained incident46 only. |

Independent review exclusively extracted XML/xcresults and matched IDs/parameter-expanded cases. Current host summaries have zero failures/expected failures/skips/runtime warnings; logs have no crashes/errors. `git diff --check` passes. Watch runners isolate both eager app hosts/79product paths; phone runner contains only its two actual targets, isolates the included phone host/33paths and does not claim a Watch host exists. Existing default-container-writing exclusions remain explicit. No new O6 UI runtime was necessary because O6 adds pure Core code and existing UI/caller inputs remain unchanged; final O11 UI remains mandatory.

## Preserved failures and scheduling rule

Missing-implementation reds01/04/06/08, initial macro-compilation failure10 and partial runtime12 remain preserved. Foundation's resolvingSymlinksInPath retained the /var alias on this host, causing test-root ENOTDIR. A7-line test-helper correction uses POSIXrealpath only on the trusted system temp root; owned/hostile children and production no-follow checks stay intact. Runtime14 then reached both actual publication fault hooks and reproduced their false successes.

Default full17 ran up to329methods concurrently and failed to establish a16-suspended-handler premise before the connection test's deadlines. Only adding explicit `--no-parallel` produced full18's peak1method/zero overlaps; the same connection test passed0.274s versus failed27.670s. Source, test assertions and deadlines were identical. This supports a resource-scheduling limitation of the default combined test run; it does not erase17 or justify a production timeout change. Full Core reproduction and future CI must explicitly pass `--no-parallel`. SwiftPM's displayed default does not automatically disable SwiftTesting's internal parallel execution. A private one-second process sample confirmed bounded journal work while the serial run was CPU-busy, rather than a stalled scheduler.

## Acceptance and remaining gates

Independent verdict: **SAFE WITH NON-BLOCKING NOTES — O6 local package only.** Root accepts the package and releases only the next reviewed O7p tests-first prerequisite. O6 now supplies tested values/storage/math for later native integration.

Physical testing remains **NOT READY**. Native HR/practice integration, whole-practice transfer/export/deletion, phone results, final integration, current pushed CI, formal committed-HEAD review and physical evidence remain open. Builds are unsigned simulator products. Original isolation incident46 and default-path exclusions remain recorded; guards do not mean original defaults were unchanged. No new physical install, Git publication or merge occurred.
