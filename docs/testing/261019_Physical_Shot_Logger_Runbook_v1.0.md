# First physical shot recording — v1.0

19 October 2026, Asia/Dubai. Authority: PSL-SPEC-001 v1.1, S1-01–10. This is an owner-led feasibility experiment, not a validated clean-hit detector. No coach or expense is required for this first test.

## Build and preflight

Local branch `feature/watch-recording-storage`, base/HEAD `ee15c0ef86c99064bb1295c7550fba1daea66a3c`; logger changes are uncommitted. Current source is identified by [the 52-file top-scan manifest](261019_Physical_Logger_Top_Scan_Code_State.sha256), SHA256 `a70de47a76f8d9fc54eb08d22d634b0d5717effa0bc6ac00dd8a692570b0d988`. Only the Watch UI test helper differs from the original signed build2 manifest; all production/build files are identical. Record this identity alongside every observation. Publication, clean CI and formal committed-HEAD review remain separate open gates; no merge or release is authorized.

Coordinator checks Xcode 27, actual connected hardware/OS, signing, phone/Watch companion relationship and separate Watch installation. End any other workout before capture. Verify both apps actually launch on hardware; simulator installations do not count. Keep personal device identifiers and raw logs private. Do not start court collection until a short dry-run recording is retrieved and exported successfully.

Deliver these steps to the owner one at a time, recording expected and actual results. Do not infer success from the instructions or a screenshot of another stage.

## First-set sequence

1. **Open Practice on the physical Watch.** Choose the playing/racket arm and handedness. The configured Watch wrist must match the playing arm; physically wear the Watch on that arm. Confirm “Watch on this arm.” Expected: setup reflects the actual arm and wrist.
2. **Tap Start recording.** Answer the system permission prompts. Expected: Starting becomes Recording only after real accelerometer and device-motion streams arrive; both live counts increase. If access is denied or capture fails, retain the exact message and stop the test. Do not repeatedly retry without diagnosis.
3. **For the first dry run, make one controlled air swing, then tap Stop and save after the movement.** Do not touch the screen during the swing. Expected: capture ends and the Watch reports locally saved/verified data or an explicit interruption. A set has a visible limit of 120 active seconds, excluding pauses. Live accepted counts and durable chunk counts mean different things; the final batched sensor tail remains unverified.
4. **Open Sessions on the iPhone.** Keep both apps available. If needed, use “Send to iPhone” on the retained Watch recording. Expected: exactly one corresponding recording arrives with a verified application receipt. A queued transfer or OS transfer completion alone is insufficient. Record duration, counts, rates, gaps, interruption notices and recording ID; compare both devices.
5. **Open the recording and tap Add attempt.** Label the dry run “Air swing,” enter confidence and the actual evidence source/note. Expected: owner provenance and revision are retained without changing raw samples. Attempt numbers are not detected shot times. Without a supported time match, the attempt stays unmatched/uncertain for analysis.
6. **Tap Prepare export, then Share recording bundle.** Choose an owner-controlled destination explicitly. Expected: an exported bundle containing original samples, metadata, timeline, all label revisions and integrity information. Verify it can be read back and matches the recording identity/counts before collecting court data. No automatic Drive/public upload occurs.
7. **Repeat with one controlled forehand contact per recording.** Label perceived clean contacts, mishits or uncertain attempts after each recording. Record contact feel separately from ball outcome. Keep normal practice conditions and compare separate practice sessions; self labels are not independent ground truth.

## Subsequent failure and recovery checks

After the first end-to-end success, test separately: pause/resume with fresh counts; wrist lowered/background capture; recording without the phone; later verified transfer and identical retransmission; permission denial; interrupted capture/relaunch with retained-data review; new-set arm confirmation reset; explicit local deletion and cancellation. Do not combine several unknowns into the first test. Capture actual OS/build, action, expected result, observation and evidence location for each case.

Deletion affects only the selected device copy and its managed local artifacts. Independent exports and the other device copy remain. Phone deletion creates a tombstone to prevent automatic resurrection; explicit restoration from the Watch is not implemented. A historical Watch verified receipt is not proof that the phone still retains its copy.

Optional video is manual and owner controlled; the app does not record video/audio. A visible reference movement may help establish correspondence, but must not be represented as precise synchronization without verification. Do not assign a clock interval from attempt order alone. Repeat a subset of labels later without showing the first answer; retain uncertain disagreements.

## Evidence and decision

Record actual devices/OS, source manifest/build, consented setup, permission results, workout state, retained stream counts/bounds, observed rates by active segment, maximum intervals, transfer receipts, export verification, battery observations and any failures. Do not publish personal raw recordings or identifiers to GitHub. A first successful recording is a logger observation; it does not establish clean-contact prediction, population accuracy, long-duration reliability or release readiness.
