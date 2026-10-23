# Motion-only guest capture — API feasibility v1.0

20 October 2026. Astra Extra High read-only investigation, recorded by the coordinator. Owner explicitly chose investigation of a distinct motion-only guest mode and accepts differing sampling/background limits and passive watchOS Health activity. All guest app data must stay separate; owner profile/Health context is used only when the owner is the wearer. No source/test/device changes were made by this investigation.

## Finding

A public non-workout API path exists for **short active-app motion recordings**. Reliable wrist-down guest padel capture remains unproved. This is not a guest-ready verdict, an equal-bandwidth claim or a promise to prevent watchOS's independent Health tracking.

Installed watchOS27 SDK and Apple documentation establish:

- `CMMotionManager` provides accelerometer and device-motion updates without an app-started Health workout, subject to actual device availability/authorization.
- Apple describes ordinary motion delivery up to100Hz versus batched800/200Hz. Requested intervals can be clamped; observed timestamps, not requested values, determine actual rate. Batched capture requires an active `HKWorkoutSession`.
- Inactive/frontmost time is user controlled and cannot guarantee sensor runtime. Always On is display behavior, not capture authority. Apps cannot programmatically extend frontmost runtime on current watchOS.
- Extended-runtime categories must match actual intended use; padel must not pretend to be therapy, mindfulness, self-care or a smart alarm. No audio/location workaround is proposed.
- `CMSensorRecorder` is a real non-workout background API but supplies fixed50Hz accelerometer-only data, deferred retrieval and no explicit Stop. It does not fit the present two-stream immediate-control contract; it is excluded from this proposed increment.

## Narrow architecture candidates

1. Separate ordinary-motion adapter, private serial delivery, original source timestamps and existing XYZ/13-component layouts. Runtime checks gate both streams.
2. Explicit active-app runtime policy; initially interrupt when leaving active state, preserving completed chunks and truthful recovery/interruption. This may limit natural wrist-down use and must be tested before participant collection.
3. Guest Start never calls Health workout authorization, `HKWorkoutSession` or historical Health queries. Do not merely suppress queries while reusing the owner's workout.
4. Preserve the owner batched adapter/runtime. Current Watch Start/Resume and pause gates depend on workout callbacks; changing only the sensor object would be insufficient. Never invent a workout-running event for the guest path.
5. Require real owner-workout/recovery shutdown acknowledgement before guest Start. Current `WatchWorkoutDriver.end()` requests termination and clears its session; its return does not prove `.ended` was observed.
6. Freeze participant, mode, source generation, requested rates, reference frame and adapter version in the new approved context mechanism. Delayed callbacks retain original attribution or are excluded.

The existing motion engine is HealthKit independent and accepts supported streams with valid rate metadata. Its bounded ingestion, chunks, 120-active-second limit and raw-v1 format can remain unchanged. Exact adapter/runtime interfaces, allowed files and failure tests need their own focused contract before edits; split adapter/runtime from participant-bound recorder adoption and remain within governance limits.

Candidate characterization requests are100Hz per stream, then a separately labelled50Hz comparison. Neither is a proven delivered rate or sufficient contact-quality bandwidth. Never silently switch rates or label ordinary capture as batched high-rate.

## Physical proof before guest collection

Use the owner first to characterize the candidate guest mode; this is not consented guest data. Measure actual rate/intervals/gaps, startup delay and callback lag for each stream. Exercise explicit controls, wrist-down, inactive/background, Crown dismissal, phone loss, termination/relaunch, partial-save recovery and verified export read-back. Test owner→guest→owner resource shutdown, delayed callbacks and failures without subject leakage. Inspect app-initiated Health calls; that cannot prove absence of unrelated watchOS passive tracking. Measure battery, thermal, queue pressure and storage. Freeze acquisition eligibility before evaluating other players.

For owner/wife rule comparisons, use the **same ordinary-motion mode, requested rates, device and runtime policy** for both, with separate subjects/sessions and untouched evaluation data. Owner batched versus guest ordinary data would confound player identity with capture mode. All sampling modes remain versioned/visible in exports and analysis.

## Sources and limits

- [Ordinary/batched comparison and workout requirement, WWDC2023 session10179](https://developer.apple.com/videos/play/wwdc2023/10179/).
- [Accelerometer interval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/accelerometerupdateinterval) and [device-motion interval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/devicemotionupdateinterval).
- [Frontmost execution](https://developer.apple.com/documentation/watchkit/taking-advantage-of-frontmost-app-state).
- [Extended-runtime eligibility](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions).
- [Deferred accelerometer recording](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/recordaccelerometer(forduration:)).

No real Watch motion, permission, runtime, battery, Health-write isolation, guest identity or transfer result was observed. Participant consent/retention, setup-wire binding, durable context, research receipts and ordinary-mode physical evidence remain prerequisites for actual guest collection. Do not call the shared-Watch workflow finished merely because profiles or APIs exist.
