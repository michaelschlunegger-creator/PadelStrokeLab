# Broader first-training readiness plan — v1.0

19 October 2026, Asia/Dubai. DRAFT: requirement clarification and approval remain pending. This plan does not change the immutable PSL-SPEC-001 v1.1 snapshot. The owner subsequently requested all training workflows, rather than forehand only, and made installation conditional on readiness to record actual training shots.

## Purpose and boundary

Provide an owner-led iPhone/Apple Watch recording instrument covering the whole training-data workflow and explicit intended shot types. Platforms remain iOS27/watchOS27; Watch stays on the playing/racket arm. Preserve blue/yellow/white presentation and native Liquid Glass where appropriate. No coach or expense is required.

The existing raw sensor engine is not inherently a forehand classifier: it records timestamped Watch movements. Its current setup and metadata nevertheless hardcode the forehand drill and `owner-forehand-logger-1`. Recording other movements under those names would misdescribe the experiment. Broad recording support does not establish validated quality assessment for any stroke.

Proposed smallest increment: select one intended shot type per short recording set on the Watch, before Start. Support forehand/backhand groundstroke, forehand/backhand volley, serve, lob, bandeja, vibora, smash and an explicitly unclassified/other drill. The final list needs owner confirmation. Keep each initial comparison set to one intended type; mixed-match automatic classification or contact-time detection is a later separately approved feature. Existing air-swing, non-stroke, clean-contact, mishit and uncertain self labels retain their distinct meanings.

## Acceptance map

| Workflow | Required acceptance |
|---|---|
| Setup | Actual handedness, playing arm, configured wrist/crown, sensor capability and intended shot type; fresh arm confirmation for every set. |
| Start/live recording | Explicit Start, actual Motion/Health permissions, workout started, both real streams arriving, truthful live counts and bounded set duration. |
| Pause/resume/stop | Acknowledged state transitions, explicit gaps, no active input changes, durable finalization or truthful interrupted status. |
| Recovery/offline | Retained bytes survive interruption/relaunch; recording can be retained without the phone; storage/permission failures stay explicit. |
| Transfer | Queued/transferring/received/verified distinction; application receipt, identical retransmission and no silent duplication/resurrection. |
| Review/labels | Show actual selected drill, build/protocol, duration, coverage/rates/gaps; editable owner labels/confidence/evidence with immutable raw data and revision history. |
| Export | Consented bundle includes original signals, selected drill, timeline, metadata, label history and integrity information; read-back verification. |
| Delete | Explicit local-copy deletion/cancellation, consistent transfer/tombstone handling, and accurate explanation of other copies/exports. |
| Physical entry test | Installation/launch on both devices, one controlled air swing, verified phone receipt and export before collecting actual contacts. |
| Court recording | Repeat short controlled sets using chosen shot types, label after movement, keep uncertainty; no automatic clean-hit score or general-player claim. |

## Bounded implementation proposal

Risk: Level3 for experimental metadata/provenance; preserve sensor, workout, store, transport, label schemas and archive format. Allowed production files: a new shared recording-drill definition; Watch ContentView; WatchRecorderModel; phone ContentView. Do not change raw capture, clocks, buffering, storage, connectivity, background/Health permissions, signing, minimum OS or historical practice schemas.

- Add an explicit stable recording-drill vocabulary separate from historical foundation practice archives. Preserve existing forehand recordings and decode behavior. Use a new named manual-training protocol identity for newly collected multi-type-supported recordings; never rewrite old metadata.
- Add a Watch drill picker available only during preparation. Snapshot its validated selection into RecordingMetadata at Start, before asynchronous workout/capture. Guard invalid stored values and forbid modifying an active set's intended drill.
- Update phone introduction/guide and Watch wording to explain manual intended type, all supported drills and the one-type-per-short-set collection method. Do not imply detected shot type, precise impact timing or technique advice.
- Update the runbook, acceptance matrix, manifests and status records with the approved scope and exact evidence.

Test contract before production edits: every stable drill value has the correct title and new metadata identity; invalid stored selection is visible/requires correction; existing forehand fixtures/archives remain unchanged; selected type is preserved through metadata codec/store/archive/export; disabled active-state selection cannot change a captured set; restarting a set requires arm confirmation; simulator remains incapable of real motion. Add meaningful Watch picker persistence/selection and phone guide regressions, retaining existing tests.

## Verification and sequencing

First preserve and finish the current independent-review correction package on `feature/watch-recording-storage`; its existing source manifest and tests do not prove this proposed increment. After owner confirms the scope and approves this plan, implement only the four-file bounded production package with tests. Freeze a new source identity, run affected core/app/UI regressions and both Release builds, produce a distinguishable signed device build, publish under the approved GitHub workflow, then obtain exact-HEAD CI and a new independent Astra review. Preserve every failure. Do not install on the owner's devices until the pre-install checks and explicit scope are satisfied.

Physical functionality remains unverified until observed on the actual paired Watch/phone. Install each app separately, confirm exact version/build and launch, then guide one action at a time through the air-swing/receipt/export run. Only after that end-to-end pass begin actual shot collection. Permissions, wrist-lowered background behavior, offline transfer, interruption recovery and battery are separate physical checks. Relevant physical evidence precedes merge readiness; user approval is still required for merge/release.

## Open decision

Does the owner mean all Stage1 training workflows plus selectable intended padel shot types, or all Stage1 workflows while retaining the original forehand-only drill? An asynchronous clarification is pending. No dependent source changes have been made under this proposal. Broader social, rankings, chat, bookings and Apple Intelligence remain governed by the staged product roadmap and have not been requested for this first logger installation.
