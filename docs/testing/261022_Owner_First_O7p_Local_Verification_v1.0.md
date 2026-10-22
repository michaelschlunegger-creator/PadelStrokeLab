# O7p observed motion-source closure — local verification

22 October 2026. Branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e` plus unpublished working tree. No Git publication, new device installation or physical readiness is implied.

Astra Extra High authored the bounded source/tests. Root ran verification and accepted independent Sol's read-only local verdict: **SAFE WITH NON-BLOCKING NOTES — O7p prerequisite only**.

## Exact scope and source

Only `PadelStrokeLab Watch App/WatchMotionSource.swift` changed in production: +104/−16 =120/160 allowed changed lines,216 total. Its native adapter forwards the existing CMBatchedSensorManager capabilities, activity flags and start/stop calls. Default construction stays nonthrowing; synthetic hardware injection requires the coherent isolated environment. Stop cancels pending authorization and returns an opaque source-bound epoch. The read-only witness checks the current epoch, absence of pending authorization and both native activity flags. Every authorize/start attempt invalidates an older epoch; stale authorization callbacks cannot stop replacement hardware.

Frozen06 includes95inputs. All94other inputs, including corrected tests03, remain byte-identical. Manifest SHA-256 `27baafdf3c923c343b39d988295e9144c06c4f238ed3066e4c7910115e49367e`; archive `b45429f9d8f43fdfe4c23994dbaa09eb592842fa317a123d530eadd1221122ed`. Source manifest is adjacent.

## Evidence

Private artifacts are under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/PhysicalReadiness1/`. Each command/result/log and available xcresult is retained. Xcode27.0/27A266a and OS27 SDKs were explicitly selected by DEVELOPER_DIR.

| Stage | Result |
| --- | --- |
| O7p02 initial tests-first build | FAILED65/5.675s, intentionally missing hardware/witness API; no runtime. Independent static review separately found a latent internal-Core-initializer access issue. |
| O7p03 tests-only correction | Only `import PadelCore` became `@testable import PadelCore`; no Core visibility/assertion change. All94 O6 inputs unchanged. |
| O7p04 corrected meaningful red | FAILED65/3.991s;36 primary diagnostic occurrences,17 unique locations/classes, only missing hardware/witness API. No runtime. |
| O7p07 build-for-testing | PASS14.744s. |
| O7p10 enumeration | PASS13.135s;62 Watch host methods selected. |
| O7p14 focused | PASS7.142s;14 exact methods/29 expanded executions; no failures/skips/runtime warnings. |
| O7p18 full affected Watch host | PASS12.451s;62 exact methods/96 expanded executions, matching enumeration. Previous48/67 plus new14/29. Zero failures/expected failures/skips/runtime warnings. |
| O7p20/21 simulator Release | Both PASS: iOS12.591s; watchOS8.093s. |
| O7p05/08/11/13/15/17/19/22 data guards | All PASS; final22/0.328s. No additional mutation since retained incident46 ONLY. Original defaults are NOT claimed unchanged. |

Both eager hosts were isolated and all79 product paths verified; a fresh UUID runner was generated for each enumeration/runtime. The existing default-container-writing exclusion remains explicit for O11's disposable-simulator prerequisite. All95 source inputs rehashed without drift; `git diff --check` passed. Core and UI predecessors were unchanged, so repeating their broad suites was not required for this isolated prerequisite; final O11 tests remain mandatory.

## Acceptance and limits

Root accepts O7p locally and releases only O7 tests-first under its approved eight-production-file/2,300-line contract. O7 must reacquire the current witness in final unsuspended MainActor admission after every await. A returned witness records an observation; it does not prove callback, writer or native-workout drain and cannot serve as permanent permission.

Physical sensor inactivity/background behaviour remains UNKNOWN. O7 native practice/HR, O8 whole-practice transfer/export, O9 paired deletion, O10 phone review and O11 final integration/CI/UI/physical gates remain open. The app is **NOT READY** for physical owner shot collection.
