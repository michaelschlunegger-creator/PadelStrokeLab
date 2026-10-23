# O5 owner Watch recording — local verification v1.0
22 October 2026. Implementation: Astra Extra High; test navigation, builds and evidence: root; independent review: Sol. **Historical local checkpoint, superseded BLOCKED by the [retirement wire defect](../reviews/261022_Owner_First_O5_Retirement_Blocker_v1.0.md). Physical testing NOT READY.** O6–O11 and formal exact-commit CI/review/device gates are unfinished.

## Exact state and scope
Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, no upstream. Remote main rechecked `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; tracked origin/main is0 behind/10 ahead. Only existing draft PRs1/2; current work remains unpublished.

[Source manifest](261022_Owner_First_O5_Source_v1.0.sha256) copies frozen42, SHA256 `7ab36ab45a7d88521dd0846f5e623b363bc3f228c0ee5bc0e2f81f94fa6ac31e`; private source archive SHA256 `dbd26de4a7a00c94450cb864c31cab17ad86661c5f8069324fee635e40b5ee4a`. Forty-eight exact-source check confirms every listed input matches. Only the main Watch UI-test file differs from frozen18,74 changed lines within100; all seven production files and host tests are byte-identical. Production remains1,797/2,400 changed lines under the [O5 contract](261021_Owner_First_O5_Execution_Refinement_v1.0.md).

O5 implements owner preparation acceptance, fresh short racket-arm/wrist/crown/fit checks, explicit Watch-local Start, immutable recording/context admission, synchronous authority fences and post-await validation, generation-bound native callbacks, real motion-engine/writer drain and observed native shutdown. It does not yet implement O7 practice-wide HR/recovery or authorize automatic shot classification/quality measurement.

## Verified local evidence
Xcode27.0(27A266a), iOS/watchOS27 SDKs, explicit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; global selection remains unchanged. Reserved Watch simulator `91757361-AEA2-41D8-9C4F-6DE5FF6365DA`; phone simulator `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`. Private evidence root: `~/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/PhysicalReadiness1/`.

| Evidence | Result | Meaning |
|---|---|---|
| Build19 / host24 | PASS44/44 method IDs,53 parameter executions, no skipped/failed/crashed tests | Frozen18 production and host tests; exact enumeration22 match, retained unchanged for42 |
| Build35 | PASS7.414s | Source34 test-only boundary correction |
| UI38 | FAILED5/6 passed,111.567s process | Foreground-return reveal still unobserved; retained failure |
| Phone Release40 | PASS52.746s | Release iOS27 compilation, dedicated DerivedData |
| Watch Release41 | PASS50.094s | Release watchOS27 compilation, dedicated DerivedData |
| Build43 | PASS4.951s | Frozen42 test navigation refinement |
| UI46 | PASS6/6 methods,98.182s process | Both strokes, unprepared denial, cancel/fresh check, background/fresh check and relaunch denial |
| Guards37/39/45/47 | PASS | No additional default-container mutation since retained incident46 ONLY |
| Exact-source48 | PASS | Frozen42 current; production/host-test/Release-consumed inputs unchanged |

Host tests exercise actual coordinator/engine/writer path with synthetic dependencies: saved sample bytes, both strokes and closure orders, pause/resume, held publication/authorization races, End/withdrawal/edit, stale callbacks, denied auth and source/writer faults. Simulator tests do not prove physical sampling, background endurance, sensor fidelity, real permission behavior, paired transfer, battery use or wrist ergonomics.

Runtime44 is beside products with fresh validated Watch host UUID and phone host `--motion-statistics-fixture=unavailable`; all79 non-runtime-injected expanded paths exist. Four included targets are accounted for. Watch UI creates fresh canonical per-test UUIDs and preserves them across relaunch; actual sensors, Health and connectivity are disabled in fixtures. Native runtime-injected XCTest dylibs are reported separately, not required to exist in preinstallation products. Runtime selection retains the same six UI method IDs and these three explicit exclusions: default-container host path test, UI launch-performance method and generated Watch launch-test class. They remain O11 obligations, not passes. Host24 covers all44 eligible app-host methods.

Independent extraction confirms all six UI46 IDs exactly match enumeration22 (trailing-parentheses normalization only), zero skipped/failed cases, and all six saved screenshots reviewed. Root viewed forehand, background-return and relaunch screenshots: consistent black/turquoise/white theme, legible native controls and honest disabled simulator Start. This is not full accessibility or physical usability evidence.

## Retained failures and limitations
Tests-first01, compiler03/05, host16 failures and harness assumptions are retained; see [actual recorder-path tests](261022_O5_Actual_Recorder_Path_Test_Refinement_v1.0.md) and [host16 correction](261022_O5_Runtime16_Test_Correction_v1.0.md). UI26,32,38 remain failed evidence. The bounded [Watch navigation correction](261022_O5_Watch_UI_Reveal_Correction_v1.0.md) preserves assertions/waits and explains exists-before-frame, actual navigation boundaries and native swipeDown for the absent-element foreground-return case. No production change was made to satisfy those UI failures; the native gesture mechanism is not claimed proven.

The earlier phone enumeration45/guard46 isolation incident remains: seven new simulator setup metadata entries, existing regular-file contents unchanged and no entries removed; Watch entries unchanged. Later guards prove no further changes only. No reset/cleanup/restore was performed and original-defaults-unchanged is NOT claimed. See [incident record](261022_Phone_Test_Runner_Isolation_Incident_v1.0.md).

No new physical install or capture, Git publication, final merge verdict or release is proven. O5 intentionally ends the native workout for every set; O7 must separately implement/review immutable practice/session ownership before spanning sets/recovery. New preparation never grants remote Start or silently reuses a context.

## Evidence artifact hashes
- `O5-24-host.result.json`: `2bea80e0f67bda2df4d62fddd91aed3584a82c6db139c248d5bcbe5f89dee6bd`
- `O5-38-ui.result.json`: `3724b14ad2b028a03ea75fc791b4e30d3f9f410ed270e97c111f8607c1818f54`
- `O5-40-phone-release.result.json`: `47308bc9aa111b2192b39c703b915e3d0fa240f3642670747b96800cfa825617`
- `O5-41-watch-release.result.json`: `c39299c4db639f2e62fbfb4ee230783091c202a098a67bd5213e435f4140d02e`
- `O5-43-build.result.json`: `6952176ef4bde1924fd41afd66819fd7dc02aa0ab2fb85a32a265628c5340781`
- `O5-44-runner.json`: `f2a85142a7c454dd420c650457d80a1ffada6bb55be5da3e5946aa2e9e3d8769`
- `O5-46-ui.result.json`: `0f2db96d0ca310abde4a4a88544b3453caa6b0c5c5862ca3216c5214c4d9c86f`
- `O5-47-postui-guard.result.json`: `5fc102767959f98be21ff4c6bc82732cc1000b7ecc28666504d2566ae5fac4a7`
- `O5-48-exact-source.json`: `b7deff3edb1486c81c523b05c665af42027c882f74f45caa5bb34f531dab7a23`
