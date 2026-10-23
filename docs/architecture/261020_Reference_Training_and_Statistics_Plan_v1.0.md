# Reference Training and sport statistics — proposal v1.0

20 October 2026, Asia/Dubai. Product-direction consolidation of separate **Astra Extra High** read-only API/architecture reviews. This is a proposed technical scope, not evidence that new sensors or classification work. Owner authorization covers the expanded objective and implementation before shot collection; focused high-risk contracts and independent review still precede dependent edits. No Git publication, TestFlight upload, invitation, installation, merge or release is authorized here.

## Authority and verified baseline

Read [product authority](../PRODUCT_AUTHORITY.md), [governance](../../ENGINEERING_GOVERNANCE.md) and [active gates](../../GATE_CARD.md). Immutable PSL-SPEC-001 v1.1 stays unchanged; the owner's dated amendments add wrist/health/movement/location/recovery statistics, reference-player selection and a small TestFlight reference cohort.

Local branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, contains preserved unpublished guided-setup/branding work. Phone-led P1 is frozen under 64-entry manifest `ca4332e66eaf46077a99df949d1d9d0d20895917c02af21db0fce24b64b15171`: two new files/560 production lines, 128 core tests/12 suites and both OS27 Release builds passed. Separate Astra Extra High review found no source blocker; formal committed-HEAD review/CI/physical gates remain open. Do not retrospectively assign participant or telemetry behavior to P1.

Existing motion capture retains accelerometer XYZ (g, including gravity), rotation XYZ (rad/s), gravity XYZ, gravity-removed user acceleration XYZ (g) and attitude quaternion XYZW with original timestamps. Phone currently displays counts, timing/rates/gaps, metadata, labels and transfer receipt. Heart rate, pedometer, GPS, recovery, a sports dashboard and automatic stroke counts are absent. The current motion recording limit is **120 active seconds**; that is an experimental recording set, not a full padel match/set. Installed physical apps remain build 4; actual capture/paired delivery/export and battery evidence are unobserved.

## Product experience

The iPhone remains the main terminal for setup, data review, graphs, profiles, export and privacy. Watch remains the sensor/logger with glanceable readings and minimal controls. Keep blue/yellow/white styling and native Liquid Glass controls where useful; charts and long reading surfaces must remain legible.

Detailed setup remains **once per practice on phone**, with saved choices and an editable summary. Every new recording requires brief local Watch physical confirmation and explicit Start. A selected reference player remains selected until deliberately changed; do not invent a mandatory phone interaction for every set. Show the player prominently on Watch before each recording. Changes during capture apply only to a future recording.

Development **Training / reference collection** is separate from ordinary consumer play. It supports Player 1/2/3 as convenient local slots. Stable pseudonymous UUIDs, not slot numbers or real names, identify participants; renaming/reusing a slot cannot change old recordings. The TestFlight objective is **5–10 players across installations**, preferably using their own paired devices. Three local slots are not a cohort maximum. Consumer play must not ask people to teach individual strokes or choose reference subjects.

Every research recording needs immutable participant, collection-mode, consent/protocol, device/capability and preparation provenance linked to recording ID and raw-data digest. Current raw metadata lacks participant identity; current labels hard-code owner self-report. Add explicit versioned self-report/observer provenance. Keep label subject, label author and device account owner distinct. Historical records remain unchanged and read as participant-not-recorded unless actual evidence supports a dated supplementary attestation.

The owner explicitly requires guest readings to appear only for that guest. Enforce subject-scoped queries and aggregates for recordings, charts, labels, exports and derived results; changing current player cannot reassign history. Slot rename/reuse and imported records must preserve immutable subject IDs. Unassigned historical records remain a separate unassigned category. Never substitute the account owner's Health history for a missing guest channel.

The account owner's profile/Health context may be used only when that person is the selected wearer. Changing participant or acquisition mode must retire prior preparation generations and close the old participant's recovery/health/location/pedometer observers before a new context can Start. Staging a next player during active capture leaves that capture unchanged; transition only after old-set finalization and resource shutdown acknowledgement. A guest cannot inherit an ongoing owner `HKWorkoutSession`. Bind every asynchronous callback and cumulative-counter baseline to its immutable subject/context/generation; a late callback stays with the old context or is excluded, never attributed using the currently selected UI profile. New participant intervals cannot bridge old counters or recovery windows.

## Useful statistics before shot-rule development

| Area | Proposed useful display | Truthful boundary |
| --- | --- | --- |
| Wrist motion | Gravity-removed peak/RMS acceleration, angular speed, XYZ/magnitude charts, segment comparisons | Wrist motion only; no body acceleration, racket-head/ball speed or clean-hit score. |
| Data quality | Captured duration, valid sample coverage, observed rates, maximum intervals, interruptions, source/mode/version | Separate unavailable and invalid values; never substitute zero or bridge pauses/gaps. |
| Heart rate | Latest BPM with observation age, timeline, observed average/maximum and readable coverage | No raw optical waveform or guaranteed beat-by-beat readings. Permission completion does not prove readable Health access. |
| Between-set recovery | Observed HR change around 60/120 seconds, actual time offsets, recovery curve | Preserve signed change; inadequate readings/early next set remain unavailable. This is not a medical normality or fitness verdict. |
| Steps | Watch-estimated steps, cadence when available, play versus recovery intervals | Shuffles and racket-arm motion need physical comparison; not exact foot contacts. |
| Distance/speed | Separate pedometer estimate and qualified outdoor GPS estimate; units, accuracy and coverage | Do not add sources together, double-integrate wrist motion, or infer exact walked/run subdivisions. |
| Optional location | Watch coordinates/timestamps/accuracy and qualified route display | Off by default; no invented indoor/court positioning or ball-placement heatmap. A courtside phone cannot supply the player's movement. |
| Health context | Optional historical VO₂ max/date/source; blood oxygen as a separate available historical record | Not live padel VO₂ max or continuous SpO₂; only the correct Health subject with explicit consent. |
| Future strokes | Versioned event detection, rule-supported stroke families, unknown/ambiguous events and eventually counts | Manual intended drill and owner-entered attempts are not automatic recognition. No validated thresholds/accuracy yet. |

An initial wrist-motion dashboard can use existing immutable recordings without requesting new sensors. Acceleration terminology must distinguish raw gravity-containing acceleration from gravity-removed user acceleration; angular motion uses rad/s or °/s. Avoid unsupported effort, sprint, calorie or movement-quality scores. Start-stop wrist activity is initially experimental, not a proven rally/run detector.

Apple derives Watch VO₂ max in eligible outdoor walking/running/hiking contexts, not from arbitrary padel play. Apple Health's stored one-minute recovery quantity is distinct from our proposed observed set-end minus post-set HR change. “Returned near pre-set level” requires an approved baseline window/tolerance/posture rule; the first increment should show the curve and qualified changes instead.

## Practice lifecycle, telemetry and privacy

Recovery cannot be added as a label to the existing workout: the current workout ends with each 120-second capture. A separately scoped practice controller must own an explicit sequence of short recordings and recovery intervals. Stop a recording and finalize it independently; a visible recovery phase may continue permitted observation. Next set closes the prior recovery window; Finish Practice ends all resources. Bound practice duration, storage and battery cost in the focused contract before implementation. Do not silently advertise full-match capture or remove the existing motion limit.

Preserve the existing two-stream raw schema and checksums. Use bounded, separately versioned participant/context and telemetry records linked to practice/recording IDs. Keep original source timestamps, units, source/device, receipt times, observation accuracy, availability reasons and derivation version. Explicitly map Health/Location wall dates to motion uptime; detect clock changes. Deduplicate Health samples and cumulative pedometer snapshots. Keep health/location availability independent from valid motion capture.

Existing archive v1 and receipts whitelist motion/timeline/labels and support exactly two stream-coverage entries. A versioned outer research bundle or deliberate archive evolution must preserve v1 reading and verify every included context/telemetry component. Do not drop provenance for an older peer or add unexpected files to raw directories. Transport, receipt, export and deletion require separate compatibility tests. Participant-specific deletion must find associated local records/labels/derivatives. Exported copies remain outside recall.

Live HR, optional historical Health context, location and research/model use need clear separate controls. Precise GPS is optional and off by default; no-location/no-HR paths must still work. No automatic cloud/Drive/public upload. Before non-owner collection, approve a brief participant information/consent and retention/withdrawal process. TestFlight acceptance alone is not research consent. Keep raw personal evidence out of GitHub.

## Shared Watch: unresolved acquisition policy

App player selection does not switch Apple Health identity. Apple documents that [all workout sessions generate high-frequency HR samples](https://developer.apple.com/documentation/healthkit/hkworkoutsession), and [running sessions automatically save active-energy/workout samples to HealthKit](https://developer.apple.com/documentation/healthkit/running-workout-sessions). `HKWorkoutBuilder.discardWorkout` does not delete samples already added. No-builder/no-workout-summary does not mean no Health writes.

Therefore, do not show the owner's VO₂ max/Health history as a guest's, or silently start a guest workout under the owner's Health identity. The owner explicitly selected **investigate a separate motion-only guest mode**, acknowledging different sampling/background limits and normal watchOS passive health tracking. Investigate public non-workout acquisition with no app-initiated Health workout/history reads; do not promise equivalent high-rate capture or complete Health isolation. Each participant's own paired devices remain the preferred full-measurement TestFlight route. No sensor-setting changes, unpairing or automatic deletion of Health records is proposed.

Profile/provenance implementation and owner-only motion charts can progress independently. Shared-Watch capture readiness cannot be claimed until its policy, API path, consent and physical limitations are resolved. Different capture modes must remain distinguishable in analysis and be compared fairly across players.

## Rule-based recognition and evaluation

Start with an interpretable pipeline: candidate event detection → bounded features → supported stroke-family rules → unknown/ambiguous or supported type. Hardware/playing-arm/wrist-crown/frame differences and non-shot movements matter; wrist patterns can overlap between volleys/groundstrokes and similar overheads. No per-variety classifier is proved merely by its rule being coded.

Use the owner's recordings to explore rules, reserve separate owner sessions untouched, then evaluate unchanged rules on consented wife/volunteer data. If another player's examples tune a threshold, they become development data and require fresh held-out evaluation. Split by player/session and capture capability, not neighbouring windows. Report event misses/false events, per-class confusion/precision/recall, count error, eligible coverage and abstention. A coach, paid appointment or large study is not mandatory for this personal feasibility work.

The analysis interfaces and unknown states can be implemented before shot collection; empirically verified thresholds, shot totals and clean-contact claims cannot precede relevant recordings. The owner will not be asked to collect shots before the agreed recording/measurement workflow is actually verified.

## Ordered bounded implementation and gates

These are package candidates, not an unbounded file-edit authorization. Freeze exact files, invariants, tests and source before each package; stay within eight production files/2,500 changed lines/two Level3 domains, splitting again as needed.

1. Complete the existing-motion dashboard contract: at most four production files, one evidence-interpretation domain; test bounded analysis, units, gaps, peaks, cancellation and raw-byte preservation.
2. Version the reference participant/context and setup binding before transport: exact participant/mode/policy/protocol identity must be covered by the canonical digest and full Watch acknowledgement. Add truthful starting/pausing/resuming states; preserve P1 as a historical checkpoint.
3. Complete the sole-owner phone-to-Watch setup transport, completion-based admission/cancellation and ephemeral current/next authority under the updated contract. No remote Start or participant reassignment of active capture.
4. Complete phone-led setup/player/consent presentation and compact Watch adoption, followed by full model/UI/premium visual checks.
5. Implement bounded practice/telemetry persistence and crash recovery, separately from motion raw files.
6. Implement versioned reference labels/bundle compatibility, then verified transfer/import/export/deletion in separately scoped packages.
7. Implement practice-level workout/HR/recovery ownership and actual persistence/permission behavior for the device-account owner; the explicitly chosen guest investigation must never silently reuse this acquisition path.
8. Add pedometer estimates, then explicit optional Watch GPS, each with separate acquisition/quality/battery contracts and physical evidence.
9. Add recovery dashboard, optional historical Health context and honest automatic-analysis interfaces in separate packages. Guest acquisition remains a separately chosen and verified capability.
10. Reconcile final source/builds/tests/UI, obtain required publication/review/CI/physical evidence, then the separately approved Training-only TestFlight process for 5–10 consented players. No invitations or distribution occur merely from this plan.

Required failure coverage includes stale participant acknowledgements, slot rename/reuse, offline/duplicate Start admission, active player change isolation, corruption/partial writes/counter resets, old exports, wrong participant/label author, late/duplicate/missing HR, early recovery termination, denied/approximate/stale GPS, stationary location drift, pause/gap boundaries, overlapping workouts and actual Health side effects. Test sensor coexistence, motion ingestion pressure, battery/storage, wrist-down/background/disconnected use and export read-back physically; simulator results cannot prove these.

## Current next action

The shared-Watch preference is resolved as an investigation of motion-only guest acquisition. Independently review/ratify the existing-motion dashboard contract and participant/setup amendment, then scope that guest API/lifecycle investigation separately. No new health/location/guest capture code is authorized by this proposal alone. Keep the integrated app and TestFlight readiness UNKNOWN until their relevant gates pass.
