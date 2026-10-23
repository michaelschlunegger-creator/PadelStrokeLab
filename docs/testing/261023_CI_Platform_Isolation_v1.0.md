# CI platform isolation

23 October 2026. Branch `feature/guided-padel-setup`; amendment base `bd9ba51999c3cad5b4708bd702b9f06bec6bbd69`. CI orchestration only; app/Core/test/build-setting/signed-product inputs are unchanged.

## Preserved failure

[CI39875729703](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39875729703) failed simulator preparation after full Core passed. Initial and post-Core inventories found available OS27 runtimes with existing bundle/root paths, including a legitimate Watch mount-path change. Phone boot completed. Before Watch boot, the global runtime scan timed out after60 seconds, inventory after30 seconds and image inventory after30 seconds. Watch boot was never attempted; Release/build/app-test steps were skipped, not passed.

Retained `CI5-artifacts` runtime reports and `simulator-setup.log` distinguish service timeouts from missing paths. Corrupt assets and the root cause remain unproven. No runtime download, deletion or repeated boot follows from these observations. Earlier failures remain in [runtime validation](261023_CI_Runtime_Validation_v1.0.md) and [worker diagnostics](261023_CI_Worker_Diagnostics_v1.0.md).

## Bounded mitigation

- Pure Core retains its exact full serialized command,15-minute limit and heartbeat, without simulator operations.
- Dependent PHONE/WATCH matrix workers verify the same submitted source,115-input manifest, Xcode27 and27.0 SDKs. Fail-fast is disabled; each platform retains a120-minute budget.
- Each worker validates/mounts runtimes only while all listed simulators are Shutdown, creates a shutdown pair, and builds selected Release and Debug test products before boot.
- Runner target enumeration and fixture argument formats remain intact; Watch hosts receive separate temporary UUID namespaces. Phone runs its complete original runner; Watch runs both original Watch targets.
- A fresh check pins selected runtime identifier/build, availability and existing current paths, and confirms both task devices remain Shutdown. Only the selected device is explicitly booted, once. No global scan/mount occurs afterward. Xcode may boot a companion; inventories record actual states.
- Baseline/final artifacts include platform/run/attempt. Final `foundation` always evaluates and explicitly requires Core and the entire matrix to succeed. Failure/skip/cancellation cannot pass it.

This is an isolation mitigation under investigation, not a proven simulator fix. No suite, assertion, individual test deadline or required gate was removed.

## Local verification and source

`Privacy-CI6-01-workflow-validation.json` records YAML parsing,19 Bash bodies and4 Python bodies passing syntax checks. All six Release/Debug/test commands and full Core step match their prior versions. Structural checks verify dependencies, build-before-boot order and unique artifacts. All16 controlled aggregate-status combinations allow only both-success. Five monitor cases verify waiting for the full workflow and rejecting missing/failed/skipped/cancelled outcomes. Four runtime fixtures verify shutdown-only scan, scan refusal with a booted device, valid remount paths and rejection of a changed build. These fixtures are not actual simulator/app execution.

Independent source review found no concrete blocker and cleared exact-head CI after parent validation. Source8 manifest SHA256 `277c757c84a9d4164659a7c08af3d793f50af9a8e781bcf42c234f293600781f`; its115 inputs differ from Source7 only in the workflow. Earlier local app/Core/test/signing evidence retains input identity; signed phone/Watch products remain version1.0/build6.

## Remaining gates

Publish, complete Core/both full platform jobs/final foundation at exact HEAD, then obtain final committed review. Verify live devices and install/launch iPhone and Watch separately without uninstalling or erasing recordings. Physical sensors, permissions, background, transfer and battery behavior require the controlled owner dry run.

Live exact-commit outcomes belong on [PR#3](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/3) and linked evidence without changing tested HEAD merely to record later observations. No installation, physical pass, merge or release is claimed here.
