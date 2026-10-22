# CI worker execution mitigation and diagnostics

23 October2026. Branch `feature/guided-padel-setup`, amendment base `cbd6c4fc17ae4456cc106bbfb3abe074d7a0d71e`. Only CI execution order and diagnostic collection change; app/Core production, all tests and measurement behavior remain unchanged.

## Preserved execution failures

[Run39864792158](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39864792158) attempt1 on worker1000000769 stalled in shared-code verification beyond its15-minute budget. At22:56:37UTC it still reported running from22:33:18. Normal cancellation completed after the server grace period. Final job120124158345 still listed that step in progress; GitHub returned no job log and zero artifacts.

Independent review approved one disclosed infrastructure-recovery attempt with all gates unchanged. Attempt2 used verified different worker1000000770/job120139116543 at the same commit. It again stalled: observation23:28:39UTC still showed the step running from23:10:26. Normal cancellation completed23:34:15UTC. Again no job log or artifact was available. Both attempts are retained as cancelled execution evidence, never passing tests. The root cause is UNKNOWN; absent output does not establish an app/Core test failure. GitHub's Actions service status reported operational.

## Bounded mitigation

Astra moved the entire unchanged Core step after source/toolchain verification and before creating/booting the task's simulator pair. Its existing dependencies are already available; it consumes no phone/Watch simulator IDs. This removes unnecessary VM overlap. Resource contention is an unproven hypothesis, not a diagnosed cause or demonstrated fix.

A best-effort baseline records UTC/source/run/toolchain, actual simulator states, memory/disk and limited process columns. A separate two-minute upload reuses the existing pinned action and allowlists only `core-preflight.log`, retaining initial evidence before Core can stall. A bounded30-sample/30-second heartbeat records resource snapshots; cleanup stops its monitor and pending sleep while preserving the original Core pipeline exit status. Process output contains command names, never arguments or environment dumps. Diagnostic collection/upload are bounded optional steps; every existing required gate and final evidence upload remains strict.

The original Swift command, `--no-parallel`, Core15-minute limit, aggregate120-minute budget, all test assertions, individual deadlines and complete suite coverage remain unchanged. No test exclusion or automatic retry is added.

## Verification and identity

`Privacy-CI4-01-workflow-validation.json`: YAML parse PASS; all11 shell bodies pass Bash syntax. Running the exact Core shell body with a controlled executable shim returns0 for input0(0.591s) and7 for input7(0.056s); both leave no test process group/monitor behind. These probe wrapper failure propagation and cleanup; they do not execute or replace Core tests. Independent read-only review clears the workflow source.

`Privacy-Final-Source6` freezes115 inputs. Manifest SHA256 `445fd7684ec752b681b28fdd551d6cda0ad214339ed44cf82ff1c4ebb285b94c`. Only the workflow differs from Source5. Existing app/Core production, all app/Core tests and signed-product input evidence remain identical, including all seven locally passing Motion UI methods. [Prior correction evidence](261023_UI_Scroll_Driver_Correction_v1.0.md) remains applicable to its inputs.

New exact-head CI and final committed review remain required. No candidate installation, physical sensor pass, merge or release is claimed. PR#3 records subsequent exact-commit CI/review and separate device outcomes without changing tested HEAD merely to record observations.
