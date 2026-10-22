# O5 actual recorder-path test refinement

22 October 2026. Director ratification of an independent non-Astra acceptance finding. This remains inside the released seven-file/2,400-production-line O5 scope and the named Watch test files. No new product feature, Core/raw-engine/motion-adapter change or physical run is released.

## Finding

The source02 coordinator tests use counter/empty admission closures. Recorder tests stop before a native running callback, while the fixture guard prevents the actual model running → motion authorization → admission → engine begin/resume path. These do not satisfy the existing first-build contract's production-path evidence requirement. O5 remains BLOCKED until that coverage and the independent review pass.

## Required tests before bounded seam implementation

Exercise the real `WatchRecorderModel` callback path and checked coordinator persistence with synthetic native-session and motion/writer dependencies. Prove at least successful begin/resume, held authorization/publication suspension followed by End/withdrawal/setup invalidation, late old-session callbacks, acquisition startup failure and actual writer-startup failure. Assert retained immutable recording/context identity, actual engine admission or refusal, source/writer closure and no new admission until required native end/drain observations. Counter-only coordinator tests remain useful but cannot replace this coverage.

Author the focused tests first and preserve the expected missing-seam compile failure before adding the seam. If a required case cannot be implemented through current public APIs within the cap, stop for reviewed scope adjustment; do not weaken the case or widen protected APIs.

## Permitted production support

Minimal internal nil/default injection seams may be added within the existing allowed `WatchRecorderModel.swift` (and already named driver/services files only where necessary). Production defaults must continue to call the real authorization, acquisition and capture engine paths. Use the existing real engine/writer with isolated synthetic sources and test-owned storage/faults when available. Do not duplicate the admission state machine, fabricate authority/consent or bypass post-suspension checks. No suspension may be inserted between final validated checks and actual engine admission.

Fixture UUID resolution still precedes eager singleton/delegate initialization. Fixtures must never invoke real connectivity, Health, recovery or motion; partial test injection must fail safely rather than accidentally enable hardware. Preserve ordinary fixture safety and stable per-test/relaunch isolation. The root executes Xcode and guards; Astra Extra High authors foundational code/tests; the independent reviewer remains read-only.

Next action: finish compilation of the already frozen public-API correction, then author the required tests-first delta under this refinement and capture its red before bounded implementation. All failed evidence stays retained; no physical readiness claim.
