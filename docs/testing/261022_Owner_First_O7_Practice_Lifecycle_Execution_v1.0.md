# O7 owner practice lifecycle — execution refinement

**Current source release:** Root accepts independently cleared tests06 and meaningful red07. Astra Extra High may implement ONLY the eight named production paths, at most2,300 readable added-plus-removed lines versus accepted O7p06, preserving the existing per-file planning bounds. Tests06/all other inputs are frozen except the two independently accepted O6 API-alignment cases in the new lifecycle test, documented below; record their corrected hash before the first production build. Root owns automation; independent Sol reviews only. This releases functional O7 source, not Git publication, installation, CI/G6/G7 or physical readiness.

22 October 2026. Root adopts independent Sol's read-only prerequisite audit as the concrete O7 plan under the approved owner forehand/backhand contract. Astra Extra High authors tests/production. Implementation waits for accepted O6 and the separate [O7p motion-closure prerequisite](261022_Owner_First_O7_Motion_Closure_Prerequisite_v1.0.md). This document releases no concurrent source changes or physical installation.

## Scope

Allow the original seven O7 production paths plus `OwnerCaptureCoordinator.swift`, with the unchanged2,300 readable added-plus-removed line cap. No Core/wire/raw-schema widening, phone-source edits or hidden helper/motion-manager implementation. Planned allocations, including deletions: new `OwnerHeartRateSource.swift`450, new `OwnerPracticeCoordinator.swift`650, `WatchWorkoutDriver.swift`250, `WatchRecorderModel.swift`400, `WatchRecordingServices.swift`100, `ContentView.swift`150, `Configuration/Watch-Info.plist`10, `OwnerCaptureCoordinator.swift`190; total2,200 with100 reserve. Exceeding the cap requires a reviewed split before implementation.

## Ownership and states

The retained Watch service owns one practice coordinator, which owns the practice-wide native workout, optional HR query, timers and exclusive O6 telemetry worker. The recorder model retains its existing per-set motion engine/source/writer. Native workout events belong to the practice coordinator and never directly authorize a set.

Immutable practice scope binds owner/installations/practice/runtime/clock and a new native-attempt UUID. The installed native handle UUID remains on that scope. Each set has a different attempt/recording/context/raw clock/calibration. Each HR callback captures consent segment, query generation and page identity before dispatch; delayed work cannot look up a newer practice or segment.

States: ready; starting/baseline; active set; set closing; between-set recovery; practice paused; ending; ended/interrupted. Local **Begin practice** starts only the legitimate workout and optional observed baseline, never motion. The owner may finish the brief physical check and explicitly start a set without a forced30-second wait; insufficient baseline stays missing. Detailed configuration remains on iPhone.

Same-practice next admission requires sealed old ingress, current O7p source-inactivity witness, actual writer terminal/drain, the same live authorized native practice, fresh exact accepted preparation/physical confirmation and a new immutable set/context with final unsuspended admission. Separate set closure from whole-practice native closure. Never call `workoutClosed` as a substitute for same-practice readiness. Reacquire `closureWitness(for:)` in the final unsuspended MainActor admission after all asynchronous publication/drain work; a previously returned witness is only a historical observation, never permanent permission.

Replacement practice requires actual native ended or verified no-session-created, HR callback closure, source inactivity and writer drain. Timeout retains blocked resources. Telemetry finalization does not acknowledge hardware shutdown. Old native events keep their practice identity; do not relabel first-set event IDs to later sets. Duplicate/late running or paused events cannot create a local set request.

Pause set retains existing raw pause/seal semantics and observed workout pause. Pause practice closes eligible observation and pauses native workout. Resume requires explicit local action and observed running; it cannot restart a stopped set.

## Authority and consent

Pending/fresh Starts and resume admission are synchronously fenced on every authority change; stale accepted-current/next presentation is cleared. HR narrowing immediately stops/fences HR. Already admitted motion may continue only through an exactly checked contiguous HR-only chain: reconstruct each transition through existing public checked APIs and prove unchanged owner/installations/policy/motion grant/withdrawal barrier. Persist the matching O6 authority segment before treating it as reconciled.

Keep original raw admission context/authority immutable. Validate its original binding separately from the checked current motion-carry proof. Pending/unadmitted capture gets no exception. Fresh sets bind current exact authority. Unknown, skipped, failed, non-HR or unreconciled transitions fail closed; duplicate transitions do not advance twice. Advance, cancellation, withdrawal and retirement are never HR-only carry events. No Core or wire validation is weakened.

## Optional native HR acquisition

Request only workout sharing and optional standard-HR reading. Never request HR writing or unrelated/history types, and never save an app workout summary. Update the usage description to explain current-practice HR and absent-data behavior truthfully.

SDK27 permits anchored-query updateHandler only with no limit. Use serial finite queries with limit256 and no update handler, one in-flight query and one coalesced wake. Fixed predicates use strict-start current-practice bounds, end no later than start+1,800seconds, and local-device predicate. Postvalidate whole intervals, local device and user-entered metadata. Count additions plus deletions <=256 before conversion. A full page continues serial pagination; empty results wait for a bounded timer/wake without repeated telemetry events.

Advance the anchor only after the real page and aggregate rejection counts are durably accepted. Persist approved machine provenance and source dates/UUID/BPM/arrival, without device names or system-local identifiers. O6 rejection events retain reason/count without rejected private payload. Nonempty native deletions durably invalidate all provisional recovery through `.sourceDeleted` and interrupt actual acquisition; do not invent retraction. Successful authorization with empty samples means **No accessible heart-rate data**, not a proven permission state.

At End, freeze cutoff/segment/query identities, stop scheduling and query, then drain already-entered counted callbacks for at mostfive seconds. StopQuery's no-future-handler guarantee is not a native asynchronous acknowledgement. Late pages cannot alter finalized content or migrate to another practice.

## Limits and clocks

Inject paired wall/monotonic readings and deadline scheduling in tests. Production uses real clocks and retained deadlines. Thirty minutes is total elapsed practice duration including pauses/rest, never reset by a set, consent or resume. Enforce20-set inventory, preserve120-active-second raw limit. Fatal publication/start failure interrupts practice rather than enabling unlimited attempts. At Stop+130seconds close recovery and request native pause, waiting for its acknowledgement. Earlier next-set/Pause/End closes coverage and leaves incomplete targets missing.

Check deadlines at admission, callbacks and transitions as well as timer delivery. Bracket raw-metadata creation with calibration readings, preserving raw clock IDs and uncertainty. Discrepancy >2seconds makes affected alignment unavailable. Background support is not proof of timely execution under all suspension; relaunch/recovery interrupts and retires previous practice without automatic recording restart.

## Tests first and review

### Bounded recovery-read audit refinement, 22 October 2026

Root accepts the independent source45/47 audit's finite correction inside the existing coordinator/telemetry-worker file and unchanged eight-file/2,300line cap. Add an internal synchronous `OwnerPracticeRecoveryReader.forEachCandidate(base:visit:)`, used by actual production recovery. Its throwing visitor receives validated `OwnerPracticeTelemetry`; it grants no capture permission and does not replace O6's checked exclusive open. Traverse/read through bounded descriptor-relative no-follow operations before decoding/visiting; reject symlinked ancestors/components, nonregular or hardlinked payloads, oversized/changed content and excessive inventory. Use frozen `OwnerPracticeTelemetry.maximumBytes` (2MiB); the approved512-practice limit permits at most1,024 paired directory/witness entries. Keep one bounded payload in memory at a time, preserve checked O6 expected-header reopening and unknown-native-closure blocking. No Core/schema/new production file, competing owner store, UI or signing change is released.

Tests first cover valid content and namespace/practice/file symlinks, hardlinks, oversized payload and directory overflow. Preserve a meaningful missing-reader-interface red; only the reader/integration correction may follow that red. Additional existing-API tests cover valid HR-disable while queued/native authorization is pending; direct End after the duration boundary without timer delivery; and a counted in-bounds HR callback whose rejection persists at its genuine entry instant despite late End. Those behavior fixes require runtime reds after the reader permits compilation; a missing-interface failure does not prove them. Maintain actual set/End times and native closure, never clamp/backdate event timestamps or invent old closure. All tests and source stay subject to exact freeze, guards, affected execution and independent review.

New Watch app-host `OwnerHeartRateLifecycleTests.swift` plus explicitly affected existing actual-path tests (`OwnerCaptureAdmissionTests.swift` and `PadelStrokeLab_Watch_AppTests.swift`) must cover real coordinators/O6 store/engine/writer with isolated hardware adapters:

- Two sets/one native session with different contexts and no between-set motion; source-first/writer-first and timeout orders; native closure required for replacement.
- Local-only Start/fresh physical check and delayed native/auth callbacks; no fabricated event correlation.
- HR revoke/regrant during recording/paused, contiguous/duplicate/gap/failure/non-HR transitions, unchanged context and encodable cleared status.
- Exact query types/predicates, finite page/addition+deletion bounds, one query, durable anchor ordering, storage/query failures, provenance rejection/privacy and source-deletion durable invalidation.
- Held callback at End, five-second drain, late callback and immutable finalization; recovery boundaries, early next-set regression, sparse/negative/missing values.
- Thirty-minute/20-set/+130 limits, delayed timers, clock/calibration uncertainty, permission/empty-HR/workout/source/writer errors and interrupted relaunch.
- Existing actual-path regression, short Watch controls, honest simulator/missing-data UI and both OS27 Release builds.

Preserve tests-first red, exact source, full affected regression, protected-data guards and independent read-only local review before acceptance. Formal committed-HEAD CI/review and physical evidence remain separate. Native cadence/background/inactivity/Health side effects remain physical unknowns.

### Tests-first file-scope clarification

Root explicitly names the affected existing app-host files above. Existing `PadelStrokeLab_Watch_AppUITests.swift` may be extended only for the new Begin-practice and short Watch-control flow, before related production changes. Preserve previous intent/safety assertions and synthetic isolation. O7p `WatchMotionClosureTests.swift` stays frozen. No product layout/style expansion is released. All changed tests must be identified, frozen and independently reviewed with meaningful missing-interface red before production release.

### Isolated drain-acknowledgement seam

Root conditionally ratifies the tests-first fixture interface; independent Sol found no blocker with these limits. `WatchRecorderModel` may accept an isolated-fixture-only `beforeWriterDrain` async barrier around observation of the existing real engine drain. After release it must still await the actual engine snapshot, require its actual terminal state and recheck exact engine, set attempt, practice and drain-request identities before acknowledgment. End, cancellation or replacement while held cannot acknowledge another generation. Tests release held barriers during cleanup.

This seam delays observation/acknowledgment, not necessarily physical writer I/O; test names and evidence must state that distinction. No fabricated closed boolean, alternate engine or widened Core seam is allowed. Services injection of workout/HR/clock/barrier requires the same coherent UUID synthetic environment, with invalid/nonfixture denial tests; production nil/default behaviour remains unchanged. All changes remain within the existing named files and total cap, and production release still waits reviewed meaningful tests-first red.

### Coherent test-clock boundary

Independent review of O7 draft01 found that an artificial practice clock at100/1,800,000,000 was incompatible with the unchanged real engine's Date/systemUptime windows. Root rejects an arbitrary engine-factory seam: the public engine snapshot cannot prove its private writer paths/configuration, and Core remains frozen.

Use genuine paired Date/systemUptime fixtures with deadline offset initially zero. During every real raw capture keep that offset unchanged and emit current systemUptime only after actual handler/start admission. Recovery/+130/30-minute checks may advance a deadline offset only after real raw Stop/drain; shutdown-timeout checks may advance it after End's cutoff is frozen. Compare query bounds to the real frozen practice header. Remove an unnecessary virtual five-second jump from the two-set identity test without weakening identity/closure assertions; use an actual bounded wait only when a duration criterion needs it. Verify no forced baseline wait by reaching recording without an artificial time advance or a mandatory30-second delay. The production provider remains actual paired wall/monotonic readings; no Core visibility widening, alternate engine or invented factory-verification claim is released.

### O7 tests02 review checkpoint

Root froze96inputs: tests02 manifest `a0c5e0002fdeda065a8c71aab3541bf3f72b7e7f58b88d0f6264a6d696e1f1dc`, archive `b05641ad0a2d921c88aed703cbfe5baf785baae2c21e7b710d4834a6153d0b5a`. Only existing `OwnerCaptureAdmissionTests.swift` changed, plus new `OwnerHeartRateLifecycleTests.swift`; all94other inputs unchanged. O7-03 meaningful missing-interface red:65/7.708s,17primary diagnostic occurrences at5locations for4absent planned interfaces; no runtime. Independent Sol verified source identities and the red but returned **BLOCKED** for tests02, with exactly three bounded corrections: wait for observable missing-dependency refusal and retain isolation proof; deliver old-generation native handlers while resumed capture is active and assert unchanged state/counts/context; cover nonfixture/invalid denial of planned services/model injection seams, beyond HR-source denial alone. Astra may correct ONLY the two named test files. Production remains frozen pending corrected freeze/red and independent acceptance.

Exact predecessor evidence already covers Core/reopen/admission contracts: `OwnerTelemetryStoreTests.openPartialCheckpointIsInterruptedAndCannotBePromotedToCleanEnd`; `OwnerPracticeTelemetryTests.calibrationBindsExactContextRawAnchorsPracticeDomainAndRuntime` (rejects>2.000001s; exact2allowed); and `OwnerCaptureAdmissionTests.duplicatePublishedIDAndRelaunchCannotRestoreAdmission`. Final O7 source must apply these contracts fail-closed, with no automatic restart, invented old-native closure or false alignment eligibility. Unsupported recovery may remain visibly blocked; no speculative recovery API is released.

The final writer-drain denial test must distinguish injection rejection from ordinary missing-owner/missing-motion refusal. Root and independent reviewer accept an internal read-only `WatchRecorderModel.initializationIssue` with semantic case `.untrustedInjectedDependencies`, within the existing model file/cap. Test the exact issue plus a control model using the same invalid services/environment and no custom callbacks/barrier, which must not report that injection-specific issue. Preserve callback/non-admission checks. This is an observable initializer-validation result, not capture authority, a bypass or a new production file. Only the new lifecycle test may change for this final correction; other tests04 stay frozen.

### Corrected tests06 accepted — production released

The three bounded tests02 gaps and final injection-proof ambiguity are resolved. Independent Sol clears exact tests06 for production release only. Manifest `4a0d2ac61e54db32629353a80d28521aaa1edfa744b6db3a7407965a8a50009b`; archive `e5f001fcee7162b7fef586f14dea0657b68dc3cf9340b5d0d7637b38525c0679`;96inputs, all95others unchanged versus tests04. Lifecycle hash `a32009729ac83c010fad153bd2e38c35d730a3f8455850b40c4de6758521d2c7`; existing Admission hash `144fee2a862a016a76dc72a73d138cdff4e4cd5e20c07db9371a5037ccab5353`. Preserved red05:65/5.345s,17diagnostic occurrences. Corrected meaningful red07:65/8.531s,18occurrences at5locations, only4missing planned interface types; no runtime or complete compilation claim. Production remains bounded by the current release above; all earlier failed evidence remains retained.

### O6 page-limit API alignment — bounded accepted test refinement

During O7 source implementation, author and independent reviewer identified a tests06 assertion that frozen O6 cannot represent through the correct native-page path: `recordEvent(.pageLimit)` persists the refusal and exclusion count, but does not insert `.pageLimit` into `incompleteReasons`. Only `appendPage` with>256 converted samples sets that flag; inventing converted samples would violate the native pre-conversion boundary. In addition, `.pageLimit` event count must be1 (one refused page), not257. O6 permits counts>1 only for its specified native rejection/deletion reasons.

Root accepts independent Sol's exact-API finding and releases ONLY that lifecycle test case for semantic correction: retain zero native conversions, no accepted samples/additional queries; assert one durable `.pageLimit` event/count1 and matching exclusion count; blocked capture; then explicitly observe required native End and actual interrupted finalization retaining `.interrupted` and `.pageLimit` absence reasons. This strengthens the planned refusal proof without Core expansion, fabricated samples or changing product behaviour. All other tests remain frozen. Record the corrected test hash before the first production build; preserve all earlier tests-first reds. Final source/tests freeze and real regression execution still apply.

Event/exclusion counters have reason-specific units: a page-limit count is refused pages, not257 samples. Later phone review/export must preserve that distinction rather than adding unlike event counters into a claimed rejected-sample total.

### Duration-limit API and eligibility-cutoff clarification

The bounded independent follow-on scan found exactly one other positive flag mismatch: tests06's `.incompleteReasons.durationLimit`. Frozen O6's natural event API does not populate it. Root accepts correction of ONLY this second lifecycle case: retain actual End request and blocked admission, explicitly observe native End, then assert interrupted finalization with `.interrupted` and `.durationLimit` in `finalization.absenceReasons`. Do not deliberately invoke invalid>1,800-second mutations for their failure-side effects, or backdate a duration event. Remaining sourceDeleted flag assertions match O6.

For a late timer, immediately fence new work and request actual resource shutdown. The policy eligibility cutoff is practice start+1,800 seconds; it is explicitly distinct from observed physical shutdown. Finalize interrupted telemetry within the defensible eligibility bound, preserving actual raw timestamps. Any unresolved raw set stop remains unknown, never replaced with an invented cutoff timestamp. Keep resources blocked until actual source/query/writer/native closure. If uncertainty prevents a defensible cutoff mapping, retain an interrupted partial checkpoint and fail closed. Final phone/export descriptions must distinguish eligible data span from actual shutdown, rather than claim native hardware ended at the policy cutoff.

This is an exact-API interpretation of the approved30-minute resource/eligibility limit, not an extension, clean-completion claim or Core/schema expansion. Original missing-interface reds remain retained; final corrected tests/source freeze, affected execution and independent source review remain mandatory.
