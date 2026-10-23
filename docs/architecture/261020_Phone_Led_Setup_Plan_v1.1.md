# Phone-led preparation — architecture and scope v1.1

20 October 2026, Asia/Dubai. Astra Extra High read-only architecture plan, consolidated by the project coordinator. Owner explicitly approved cadence A and the phone-led product flow on 20 October. This revision incorporates the independent architecture challenge. Technical implementation ratification awaits the independent recheck; no high-risk source has changed.

## Authority and preserved baseline

The owner requires the majority of setup on iPhone because Watch is too small for a full wizard. This supersedes the six-page Watch UX, while retaining fresh physical confirmation before every new set. The current Padel Master name, blue/yellow/white design, native Liquid Glass where appropriate, OS27 baseline and owner-led recording experiment remain binding.

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Preserve all local guided-setup/branding changes. Initial branding source is the immutable 60-entry manifest `9112e8cf7be7d00dc3ba645e4828c3ef2925a8bee171ca9068eb663918bfb2d9`; a separate bounded phone accessibility correction is in progress. Reconcile and freeze its final source before starting this package. No commit/push/new PR, physical replacement, merge or release is authorized by this proposal.

## Player experience

For first-use owner reference collection, phone **Let’s Play** opens three compact visual pages:

1. **You and your racket:** current racket hand/arm, separately labelled usual handedness and intended shot type. Remembered preferences remain editable suggestions.
2. **Wear your Watch:** arm-specific move-if-needed guidance, comfortable secure-fit instructions, and actual last-reported wrist/crown settings. Expandable instructions explain manual changes through Apple’s iPhone Watch app → My Watch → General → Watch Orientation, with Watch Settings as a fallback. Apple’s official guide confirms this phone route; actual OS27 device labels still need observation. Our app cannot programmatically change watchOS orientation or detect actual placement/fit.
3. **Send to Watch:** concise summary, explicit send/prepare action, and truthful delivery/attention status. A matching acknowledgement reads **“Setup received. Confirm on your Watch.”** Existing recording/recovery access stays available. Subsequent practices open a quick review of remembered choices with Edit and Send, rather than forcing the player to repeat the full onboarding pages.

Watch replaces six setup pages with one short preparation card: **shot • racket arm**, actual wrist/crown, fresh **“On my racket arm and secure”** confirmation, then **Start recording**. The player also confirms crown orientation matches actual wear. Mismatch, unknown wrist/crown, unsupported capture or another local blocker gets one clear explanation. Start rechecks actual settings and consumes the per-set confirmation. No remote Start, automatic start, phone-only placement assertion or inferred permission success.

Phone status distinguishes draft, sending, received, staged for next set, awaiting Watch confirmation, needs attention and last reported state. Sending is not receipt; receipt is not capture readiness; a live response is a snapshot, not a lasting guarantee.

## Confirmed product direction and technical defaults

The owner explicitly selected **A: setup on phone once per practice; briefly confirm wrist/fit and Start each subsequent set on Watch**. Do not ask this decision again. Preferences and the initial reference shot choice are remembered; changes happen on phone. A quick repeat-practice summary is sufficient, with the detailed guide available through Edit/help.

The owner also clarified that iPhone is the main terminal for setup, statistics, history and analysis. Watch remains the sensor/logger, minimal session controls and glanceable results. Heart rate, steps and estimated distance require a later bounded API/permission/measurement increment; they are not implemented or silently added here.

Manual intended-shot selection is for this owner's **development reference-data collection only**. No algorithm has yet been trained. The later consumer app should record normal play, automatically recognise validated shot varieties and estimate supported contact quality; users must not configure/teach individual strokes. Automatic recognition and quality inference are separate future implementation/validation work, not a capability supplied by this setup handoff. Keep the current 120-active-second test-set limit visible; do not market the prototype as full-match capture.

Technical defaults under the approved cadence: **End practice** and Watch process relaunch retire current practice acceptance; remembered settings remain. There is no invented time-based expiry. Unchanged subsequent sets can start without a reachable phone while that accepted practice remains active, always with fresh local physical confirmation and explicit Start. New/changed setup requires actual explicit phone preparation delivery. A relaunch can require a quick phone review/Send, never re-entry of all profile or stroke details.

No recording hierarchy or raw archive schema is added; a preparation identifier tracks setup only. The project director ratifies these bounded defaults after the independent safety recheck. Publication, physical replacement, merge and release remain separately gated.

## One transport owner and typed messages

The existing `PadelCore.RecordingConnectivity` owns `WCSession.default`, its delegate and serialized work. Phone `RecordingLibraryModel` and Watch `WatchRecordingServices.shared` already create this owner. Extend that owner; do not introduce a second delegate/coordinator.

- Use separately namespaced, typed version-1 setup payloads: sender installation epoch, preparation ID, monotonically increasing revision, canonical payload digest, current racket arm, usual handedness and supported intended-shot raw value. Do not transmit physical confirmation, quality scores or permission-success claims as facts.
- `updateApplicationContext` carries only the latest bounded draft. It is a suggestion/delivery channel, never start authorization. An explicit phone preparation request uses interactive messaging and a current Watch acknowledgement.
- Bind the explicit request to both the Watch’s fresh runtime generation and its current preparation generation, obtained through a status/request exchange. Watch-local End practice retires accepted preparation, clears current/next acceptance and rotates preparation generation even when the phone is offline. Prior-generation delayed requests and exact old-request replays fail closed; remembered drafts cannot reactivate practice. Identical duplicates within a live generation return the existing result without creating a practice or replenishing per-set confirmation.
- Phone End/cancel is only requested/pending until a matching Watch acknowledgement confirms retirement. Cancel of an in-flight preparation retires its identity/generation; leaving a local card merely clears its physical confirmation and must not be confused with End. Neither local nor remote End/cancel may stop, reset or mutate active capture; its metadata is already frozen, and the next set requires renewed setup. Generation rotation plus bounded persisted high-water bookkeeping avoids unbounded replay tombstones.
- Watch receipts echo preparation ID/revision/digest and Watch generation, with Watch-authored state, known wrist/crown and capability status. Represent unknown explicitly. Do not declare ready without a live foreground recorder/status source.
- Reject older revisions, conflicting content for the same identity/revision, unknown versions/enums, invalid or oversized payloads and invalid origin changes. A new sender epoch requires deliberate setup, not silent replacement. Atomically persist validated identity/revision/digest high-water bookkeeping before an acceptance acknowledgement; storage failure/corruption fails closed. Persist only bounded latest records, not unbounded history or per-set start consent.
- A phone edit immediately invalidates its previous matching acknowledgement. Delayed receipts cannot turn a newer draft green. Cache only **last reported** status with observation time; refresh before claiming a current snapshot.
- Coalesce the latest draft and bound interactive admission using the existing transport queue budget. The existing synchronous submit closure’s defer cannot represent a later MainActor task. Give each admitted interactive operation a completion/lease which remains counted through actual actor validation and reply/error completion. Revalidate runtime/preparation generations, cancellation and live recorder on actor entry, before any acceptance. Complete/release exactly once, including busy, lifecycle cancellation and error; cancelled work cannot later commit acceptance. Background drain cannot report success while an admitted actor operation remains pending. Preserve recording-file and `PSLReceipt1` routing, existing queue protections and background ownership. No polling or delivery deadline is promised.

## Persistence, lifecycle and recording boundary

Persist preferences, latest validated draft and identity/revision bookkeeping separately from recording directories. Never persist physical confirmation or per-set start authorization. Application-context replay alone cannot reactivate practice after Watch relaunch. Phone relaunch preserves the draft, but current readiness is unverified until refreshed.

Maintain three distinct states: **latest draft suggestion**, **explicitly accepted current setup**, and **explicitly accepted next-set setup**. Application context can update only the suggestion, including while recording. A draft must never become accepted merely because capture stops or the next set begins. Only a successfully accepted explicit preparation request can enter accepted-current/accepted-next state. Promote an accepted next-set identity only after matching generation, origin, revision and digest are revalidated, then require fresh physical confirmation.

During capture, accepted phone updates are explicitly **for the next set**; active metadata, actual settings snapshot, recording ID, buffers and controls remain untouched. Retiring preparation authority never invalidates the independent frozen active-capture snapshot.

Start validates the exact accepted revision, current actual wrist/crown, local capability/storage and fresh confirmation before freezing the existing recording metadata. Settings change, new proposal, cancelled preparation and pre-start foreground loss clear confirmation. Missing/unknown wrist or crown blocks readiness. Capture cannot depend on a continuing phone connection; phone disconnect, termination or draft changes must not stop/reset an active set. Existing pause/resume, interruption recovery, retained originals, transfer, annotations, export and deletion semantics remain unchanged.

## Bounded implementation packages

Each package is capped at eight production files, 2,500 changed lines and two Level3 domains. Define its final tests and freeze the preceding source before edits. Preserve local work and continue the authorized feature branch; do not reset to HEAD and lose branding. Publication/branch strategy is separately approved at the concrete checkpoint.

| Package | Allowed production files | Risk domains |
| --- | --- | --- |
| 1 — message/store contract | New `Packages/PadelCore/Sources/PadelCore/PracticeSetupMessages.swift`, `PracticeSetupStore.swift` | Setup identity/metadata; bounded persistence. |
| 2 — transport | Existing `Packages/PadelCore/Sources/PadelCore/RecordingConnectivity.swift`; new `PracticeSetupChannel.swift` | WatchConnectivity; ordering/concurrency. |
| 3 — phone flow | New `PadelStrokeLab/PracticeSetupModel.swift`, `PracticeSetupView.swift`; existing `RecordingLibraryModel.swift`, `PadelStrokeLabApp.swift`, `ContentView.swift` | Preparation authority; UI/state integration. |
| 4 — Watch adoption | Existing Watch `WatchRecordingServices.swift`, `WatchRecorderModel.swift`, `WatchPreparationState.swift`, `WatchPreparationView.swift`, `ContentView.swift` | Preparation authority; lifecycle invalidation. |
| 5 — integration/evidence | Bounded build-number, source-manifest and CI-reference maintenance only | Build/source identity; no new capture behavior. |

Forbidden: recording schemas/protocol identifiers, capture engine/hardware adapters, raw recording storage, archive/export/delete semantics, signing, permissions, unrelated UI/features, cloud/accounts, expenses, hidden starts, automatic contact quality or undocumented system-settings URLs. The Apple SDK confirms public application-context/message/reply/activation/reachability and read-only wrist/crown APIs; physical navigation labels still need observation.

## Test contract

- New core message/store/channel tests: literal wire contract, strict validation, draft/crash/relaunch state, exact duplicates, older revisions, conflicting digest, sender/Watch generation changes, stale acknowledgements, confirmation consumption, cancellation, busy/full queues, malformed/oversized input and application-context replay.
- Extend connectivity tests: coexistence with file and recording-receipt traffic, activation/deactivation/reachability/background drain. Setup failures must never mark a recording transferred, delete files or weaken existing bounded queues.
- Phone model tests: editable/persisted drafts, pending/current/last-reported distinctions, delayed replies, missing Watch/capability and active-capture edits. Retain existing recording-library tests.
- Watch production-path model tests: both arms/all shot types, exact setup provenance before Start, immediate stale-setting checks, single-use physical confirmation, new-set cadence, foreground/relaunch invalidation, pending updates and every active/terminal state.
- Replace obsolete six-page Watch UI expectations with the approved compact flow; preserve behavior coverage for mismatch, stale consent, lifecycle, recovery and retained controls. Phone tests cover three-page setup, Back/edit/send/error/status, largest-text portrait/landscape and unchanged session/reference navigation. Test-only seams may isolate unavailable hardware/connectivity without changing production defaults or inventing actual paired delivery.
- Run full affected automation/builds with explicit target filters and no automatic retries. Preserve every failure, source manifest and result. Inspect real simulator light/dark/accessibility screens; synthetic data evidence must be labelled.
- Obtain fresh exact-source independent review/CI under the Git approval policy. Then observe actual physical phone-to-Watch setup, system-setting correction, second-set cadence, relaunch/replay, active-edit isolation, disconnect during capture and verified save/phone receipt/export read-back before ball contacts.

## Independent challenge regression cases

1. End on Watch while phone is offline; replay identical/older/in-flight preparation and context. Practice stays ended. Phone End stays pending until its matching receipt. End/cancel during capture leaves capture unchanged.
2. Receive only a context draft during capture, stop, then prepare another set. The draft stays a suggestion. An explicitly accepted next-set identity can promote only with matching generation/origin/revision/digest and fresh confirmation.
3. Block actor handling after transport admission, request background drain, retire generation/recorder, then release the handler. There is no premature successful drain, stale acceptance or duplicate completion; recording-file/receipt semantics remain unchanged.
4. Crash or storage failure before acceptance acknowledgement cannot create a reusable acknowledgement or revive authority. Persisted preferences remain separate from confirmation. No setup provenance field is silently added to existing raw recording schemas.

## API guidance and readiness

Apple’s official orientation guide: https://support.apple.com/en-ae/guide/watch/apd0bf18f46b/watchos . It explicitly permits manual orientation changes in the iPhone Watch app. Installed public SDK APIs were verified by the architecture author; physical menu labels, sensor behavior and paired handoff remain unobserved.

Branding builds and old wizard tests do not establish this new flow. The owner-approved phone-led scope/cadence and later automatic-analysis vision are now clear. No high-risk implementation has begun. Next: independent recheck of these three clarified contracts, project-director technical ratification, then bounded packages in order. Preserve the separately approved branding/accessibility work, obtain fresh evidence and observe paired physical dry-run/export before calling the app ready for court data collection.
