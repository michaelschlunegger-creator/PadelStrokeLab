# CI OS27 runtime validation

23 October 2026. Branch `feature/guided-padel-setup`; amendment base `c8cbb67efb35be3be539b1d6bf2392179c29615a`. Workflow-only correction; app/Core production and every test source remain unchanged.

## Preserved remote outcome

[CI39872894389](https://github.com/michaelschlunegger-creator/PadelStrokeLab/actions/runs/39872894389) FAILED during simulator preparation. Full Core passed388 tests in 29 suites in334.055 seconds; the entire required step passed in6 minutes 49 seconds. Baseline collection/upload succeeded. Its retained baseline records7 GB RAM and 3 CPUs and20 shutdown simulators before Core. These observations do not prove the cause of prior worker stalls.

Phone boot succeeded. First Watch boot returned NSPOSIXErrorDomain code 2: `Unable to boot device because we cannot determine the runtime bundle. No such file or directory`. Cached pre-Core inventory had marked watchOS27.0/build 24R362 available. Subsequent Release/build/app-test steps were skipped and are not passing evidence. Retained `simulator-setup.log`, runtime inventory, Core log and worker heartbeat preserve this outcome. Image corruption or stale mounting is not established as the cause.

## Bounded correction

Astra adds a three-minute no-boot runtime preflight before Core. The documented `simctl runtime scan-and-mount` operation precedes fresh runtime and disk-image inventories. The helper requires one available exact 27.0 runtime per platform, nonempty identifier/build and existing absolute bundle/runtime-root directories. Each command is bounded at 60/30/30 seconds; stdout/stderr and a status report are retained even on invalid paths.

Simulator creation uses a new post-Core inventory instead of cached pre-Core metadata. After phone boot, immediately before the first Watch boot, another scan/fresh snapshot must validate the same selected Watch runtime identifier/build and current mounted paths. Legitimate mount-path changes are allowed. Missing/unavailable/changed identity fails before boot. There is no boot retry, platform fallback, runtime deletion, download or import.

Core remains before VM startup with its unchanged command and 15-minute limit. Aggregate 120-minute budget, all assertions, complete app/Watch suites and every existing required gate remain unchanged. Mount visibility is a prerequisite, not image-integrity or app-behavior proof. Actual first-attempt OS27 boots and complete remote suites remain required.

## Local verification and source identity

`Privacy-CI5-01-runtime-validation.json`: YAML parse, all 12 Bash bodies and three embedded Python bodies pass. Four controlled command-fixture cases pass: valid remount permits one phone/one Watch boot using fresh paths despite a deliberately stale cached inventory; missing pre-Core path fails with no boots; changed availability before creation fails with no boots; changed Watch build after phone boot fails before Watch boot. These execute the actual guard/creation shell bodies against controlled CLI responses; they do not boot real simulators or execute app/Core tests. Independent source review clears the workflow.

`Privacy-Final-Source7` freezes 115 inputs. Manifest SHA256 `eb8a533ebba9de0749676717a8b9cc81865a7905f274cd8772f8891658dfcc8c`. Only workflow differs from Source6. All app/Core production, test and signed-product input evidence retains identity, including seven locally passing Motion UI methods. [Earlier diagnostics](261023_CI_Worker_Diagnostics_v1.0.md) and [UI correction evidence](261023_UI_Scroll_Driver_Correction_v1.0.md) remain historical proof for their inputs.

New exact-head CI and final committed review are pending publication. No installation, physical sensor pass, merge or release is claimed. PR#3 records later exact-commit CI/review and separate device outcomes without changing tested HEAD merely to record observations.
