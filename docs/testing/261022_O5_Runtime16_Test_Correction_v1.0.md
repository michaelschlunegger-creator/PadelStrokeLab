# O5 runtime16 diagnosis and bounded test correction

22 October 2026. Independent non-Astra source/result review; director ratification. Source10 built successfully in11. Watch enumeration14 selected44 host/6 UI methods with three explicit exclusions. Both included host targets had early isolated launch arguments. Runtime16 failed; no UI run followed. Guard17 found no further default-store changes since incident46.

## Retained results

Runtime16:44 host methods,37 passed/7 failed,0 skipped; parameter execution53 includes43 passed/10 failed. Two legacy test-harness index crashes are retained with their crash attachments. Process exit65/72.676 seconds. These failures are not passed evidence. Review identified three concrete test-assumption errors; no production behavior change is justified by this run alone.

## Approved test-only correction

Only `PadelStrokeLab Watch AppTests/OwnerCaptureAdmissionTests.swift` may change, maximum200 changed lines against source10. All production/Core/adapter/engine files stay frozen.

1. The real engine enters recording only after both streams have delivered samples. The current helper waits for recording before emitting any samples. Require the captured source start, emit the first fresh stream pair through its generation, then require recording. In the success case, remove its now-duplicate first emission and preserve exactly one sample per stream before pause. Resume must require the second start, verify same engine/new generation, emit the resumed pair, require recording, and retain exactly two samples per stream on disk. Other callers must count any extra pairs explicitly. No broadened counts, timeouts or reordered authority checks.
2. Legacy resource-path fixtures currently omit synthetic motion and therefore use unsupported native simulator metadata before reaching native authorization. Supply the already reviewed cohesive synthetic motion dependency. Replace unsafe captured-array indexing after nonfatal waits with throwing requirements so failure is reported without crashing. The deliberately incomplete no-motion fixture must continue to fail before authorization: assert early terminal state, zero native authorization/source starts, no raw capture or hardware fallback; do not demand an impossible later phase.
3. Ending a practice intentionally changes public context inspection to retired while retaining context payload bytes. For held End cases, require retired and independently compare exact test-owned context/metadata bytes before and after, with public canonical decode where available. Other mutation cases retain valid-context assertions. Do not change Core retirement/replay semantics or weaken immutable-byte proof.

All original runtime failures remain retained. No production fix, retry without changed source, source reset or physical installation is released. After the new exact-source freeze, compile and execute the corrected host suite once with a new early process UUID and the established guards. Independent review of the correction/results remains mandatory before O5 acceptance and the pending UI run.
