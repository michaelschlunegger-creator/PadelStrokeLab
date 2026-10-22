# O7 prerequisite — observed motion-source closure

22 October 2026. Root's bounded execution refinement, informed by independent Sol's read-only SDK/current-source audit. Astra Extra High authors foundational source/tests after O6 acceptance. This document defines a prerequisite; it releases no concurrent O6 scope expansion and makes no physical-readiness claim.

Independent Sol reviewed this exact bounded plan and found no plan blocker. Root accepts it for the later tests-first O7 prerequisite; source release still waits for O6 acceptance.

**Current release:** O6 locally accepted. Astra Extra High added only the new Watch tests, then corrected one import to `@testable import PadelCore` after independent review found a latent internal-initializer access problem. No Core visibility changed. Frozen O7p03 has 95 inputs; all 94 O6 inputs remain byte-identical. Tests-first build O7p04 failed only on the intentionally absent hardware/witness API, independently confirmed by Sol: exit 65/3.991 seconds, 36 primary diagnostic occurrences, 17 unique locations/classes. No tests ran. Root accepts this meaningful red and releases ONLY `WatchMotionSource.swift`, at most 160 added-plus-removed lines against O6 source15; tests03 and every other input remain frozen. Root verifies automation; Sol reviews only. Native integration and physical readiness remain held.

## Problem and scope

`WatchMotionSource.stop()` invokes both native stop methods but returns no observable closure state. O7 must distinguish a stopped set's ingress/source/writer from the practice-owned native workout and HR query. Calling stop and draining a writer alone cannot demonstrate that both SDK motion activity flags are inactive.

Keep this prerequisite separate from O7's conditional eight-file/2,300-line scope. Allow only `PadelStrokeLab Watch App/WatchMotionSource.swift`, at most160 readable added-plus-removed lines, and one new app-host test file `PadelStrokeLab Watch AppTests/WatchMotionClosureTests.swift`. All other source/tests/configuration remain frozen. No native-session ownership, model wiring, HR, Core/schema, permissions, signing, transport or product-UI changes belong here.

## Required behavior

- A MainActor hardware adapter forwards the existing CMBatchedSensorManager start/stop operations, capabilities/rates/authorization and activity flags. Production defaults use the same native manager and retain current simulator/hardware restrictions. The adapter is a hardware test seam, not a second motion implementation.
- A custom adapter requires the existing isolated synthetic environment; invalid/absent fixture identity must never enable hardware or redirect real app storage.
- Stop cancels authorization identity/timer and invokes both stop methods. A read-only witness is bound to the current opaque stop epoch and exists only while authorization is inactive and both SDK activity flags are false.
- Any new authorization/start invalidates old witnesses. Late authorization callbacks cannot complete, restart capture or reuse a prior epoch. Repeated Stop stays safe.
- A witness reports current SDK state; it is not a callback-drain acknowledgement. Engine ingress sealing and actual writer drain remain separately required. O7 will combine these facts and bound its wait to five seconds; timeout blocks next admission.

## Tests and sequence

Tests first must drive the actual wrapper through the isolated adapter: both initially active; both stop methods invoked; either flag active denies witness; both false permits current witness; new authorization/start denies old witness; late callback after cancellation ignored; repeated stop; partial start/error closure. Preserve native-default simulator rejection. Deterministic tests do not assert real sensors stopped.

After a meaningful tests-first failure, release only the bounded source correction. Freeze, run focused and affected Watch-host regressions, both OS27 Release builds, protected-data guards and independent read-only review. No unchanged retry, assertion weakening, personal-data cleanup or Git/device action is released. Default-path tests retain their existing isolation prerequisites.

## Separate HR API constraint

SDK27 permits an HKAnchoredObjectQuery update handler only for a query with no limit. O7's256-item page contract therefore requires serial finite anchored queries without updateHandler. Advance an anchor only after the real page is durably accepted; count additions and deletions together before conversion. Bounded polling/wakes and at most one in-flight query avoid unbounded delivery. StopQuery's documented no-future-handler guarantee plus counted entered callbacks and a five-second drain is app-owned closure; do not invent a native asynchronous stop acknowledgement. Concrete O7 planning remains separately reviewed before source edits.
