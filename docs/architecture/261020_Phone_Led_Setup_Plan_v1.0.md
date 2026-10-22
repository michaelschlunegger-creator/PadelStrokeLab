# Phone-led preparation — proposed architecture and scope v1.0

20 October 2026, Asia/Dubai. Astra Extra High read-only architecture plan, consolidated by the project coordinator. **PROPOSED; owner approval required before high-risk implementation.**

## Authority and preserved baseline

The owner requires the majority of setup on iPhone because Watch is too small for a full wizard. This supersedes the six-page Watch UX, while retaining fresh physical confirmation before every new set. The current Padel Master name, blue/yellow/white design, native Liquid Glass where appropriate, OS27 baseline and owner-led recording experiment remain binding.

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`, branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Preserve all local guided-setup/branding changes. Initial branding source is the immutable 60-entry manifest `9112e8cf7be7d00dc3ba645e4828c3ef2925a8bee171ca9068eb663918bfb2d9`; a separate bounded phone accessibility correction is in progress. Reconcile and freeze its final source before starting this package. No commit/push/new PR, physical replacement, merge or release is authorized by this proposal.

## Player experience

Phone **Let’s Play** opens three compact visual pages:

1. **You and your racket:** current racket hand/arm, separately labelled usual handedness and intended shot type. Remembered preferences remain editable suggestions.
2. **Wear your Watch:** arm-specific move-if-needed guidance, comfortable secure-fit instructions, and actual last-reported wrist/crown settings. Expandable instructions explain system setting changes. The phone cannot change watchOS orientation or detect actual placement/fit.
3. **Send to Watch:** concise summary, explicit send/prepare action, and truthful delivery/attention status. A matching acknowledgement reads **“Setup received. Confirm on your Watch.”** Existing recording/recovery access stays available.

Watch replaces six setup pages with one short preparation card: **shot • racket arm**, actual wrist/crown, fresh **“On my racket arm and secure”** confirmation, then **Start recording**. The player also confirms crown orientation matches actual wear. Mismatch, unknown wrist/crown, unsupported capture or another local blocker gets one clear explanation. Start rechecks actual settings and consumes the per-set confirmation. No remote Start, automatic start, phone-only placement assertion or inferred permission success.

Phone status distinguishes draft, sending, received, staged for next set, awaiting Watch confirmation, needs attention and last reported state. Sending is not receipt; receipt is not capture readiness; a live response is a snapshot, not a lasting guarantee.

## Owner decisions to approve

| Choice | Recommended default | Alternative |
| --- | --- | --- |
| Preparation cadence | **A:** phone setup once per practice; each further set requires quick fresh Watch confirmation and explicit Start. Phone handles changes. | **B:** prepare every new set on phone, then confirm/start on Watch. |
| Practice lifetime under A | **End practice** and Watch process relaunch end the accepted practice. Remembered choices remain suggestions. No invented time expiry. | A different lifetime needs an explicit rule and tests. |
| Phone unavailable between unchanged sets under A | Allow quick repeats within the currently accepted practice, always with fresh Watch confirmation. New/changed setup needs delivery from phone. | Require phone reachability between sets. |

No recording hierarchy or raw archive schema is added; a preparation identifier tracks setup only. The actual cadence answer remains pending. A/B approval must precede dependent implementation.

## One transport owner and typed messages

The existing `PadelCore.RecordingConnectivity` owns `WCSession.default`, its delegate and serialized work. Phone `RecordingLibraryModel` and Watch `WatchRecordingServices.shared` already create this owner. Extend that owner; do not introduce a second delegate/coordinator.

- Use separately namespaced, typed version-1 setup payloads: sender installation epoch, preparation ID, monotonically increasing revision, canonical payload digest, current racket arm, usual handedness and supported intended-shot raw value. Do not transmit physical confirmation, quality scores or permission-success claims as facts.
- `updateApplicationContext` carries only the latest bounded draft. It is a suggestion/delivery channel, never start authorization. An explicit phone preparation request uses interactive messaging and a current Watch acknowledgement.
- Bind the explicit request to the Watch's fresh runtime generation obtained through a status/request exchange. Prior-generation delayed requests fail closed. Identical duplicates return the existing result; they cannot create another practice or replenish a consumed per-set ticket.
- Watch receipts echo preparation ID/revision/digest and Watch generation, with Watch-authored state, known wrist/crown and capability status. Represent unknown explicitly. Do not declare ready without a live foreground recorder/status source.
- Reject older revisions, conflicting content for the same identity/revision, unknown versions/enums, invalid or oversized payloads and invalid origin changes. A new sender epoch requires deliberate setup, not silent replacement.
- A phone edit immediately invalidates its previous matching acknowledgement. Delayed receipts cannot turn a newer draft green. Cache only **last reported** status with observation time; refresh before claiming a current snapshot.
- Coalesce latest setup updates and bound message admission. Every request/reply must complete exactly once, including busy/error cases. Preserve recording-file and `PSLReceipt1` routing, queue capacity protections and background-drain accounting. No polling or delivery deadline is promised.

## Persistence, lifecycle and recording boundary

Persist preferences, latest validated draft and identity/revision bookkeeping separately from recording directories. Never persist physical confirmation or per-set start authorization. Application-context replay alone cannot reactivate practice after Watch relaunch. Phone relaunch preserves the draft, but current readiness is unverified until refreshed.

New proposals affect preparation only. During capture, phone edits are explicitly **for the next set**; active metadata, settings snapshot, recording ID, buffers and controls remain untouched. Apply the latest pending proposal only when preparing the next set and require fresh confirmation.

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

## Readiness and next action

Branding builds and the old wizard's tests do not establish this new flow. No phone-led setup code has been changed. Next: independent architecture challenge, owner cadence/lifetime/offline-repeat decision and approval of this plan. Then implement the bounded packages in order and collect new evidence before calling the app ready for the first physical logging test.
