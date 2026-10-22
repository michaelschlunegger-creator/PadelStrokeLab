# Phone-led preparation — implementation ratification v1.0

20 October 2026, Asia/Dubai.

## Owner scope approval

The owner explicitly chose **phone setup once per practice; briefly confirm wrist/fit and Start each set on Watch**. The owner then reinforced iPhone as the main setup/statistics/analysis terminal and Watch as the logger/sensor with brief readouts. The three-page first-use phone flow, quick remembered-choice review for later practices, and one compact Watch confirmation card implement that approved direction. Do not reopen the cadence decision or preserve the six-page Watch wizard as final UX.

The owner clarified the later consumer experience: play normally with automatic recognition of supported shot varieties and validated contact-quality estimates. Users should not configure/teach individual strokes. The initial owner's manual intended-shot choice and self labels are development reference collection only. No recognition algorithm is trained. Heart rate, steps, estimated court distance, full-match capture and automatic stroke/quality inference require separate future bounded implementation/validation; do not silently add them or imply they work today. The existing 120-active-second recording limit stays visible.

## Architecture clearance and director decision

Separate Astra Extra High architecture review approved [plan v1.1](261020_Phone_Led_Setup_Plan_v1.1.md), exact SHA-256 `a9b208d9d4cf2887a5ad90893f163e3914bcf1a4348c641c76fe6af9f5d77654`. The reviewer found the three prior blocking gaps closed: End/cancel retirement and replay fencing, draft/current/accepted-next separation, and completion-based asynchronous admission with actor/generation revalidation. Atomic bookkeeping before acknowledgement and unchanged raw schemas are explicit.

The project director ratifies this bounded technical plan for the owner-approved flow. **Implementation may proceed in the ordered packages after the current interim UI run is finished and its baseline frozen.** This is local implementation authorization, not Git publication, installation, merge, release, actual paired-delivery evidence or formal committed-HEAD review.

Mandatory precision from independent review: every setup receipt/error correlation carries and checks **both `runtimeGeneration` and `preparationGeneration`**. Singular references to Watch generation in the plan cannot reduce that two-generation invariant. Watch-local End works offline and retires generation/acceptance; phone End remains requested/last-reported until acknowledged. Neither affects an already frozen active capture. App-context drafts remain suggestions unless an explicit preparation request is accepted. An admitted async operation remains counted until exactly-once completion/error/cancellation prevents all later state mutation.

Accepted defaults: End practice and Watch relaunch end ephemeral practice acceptance, while preferences stay remembered. No invented expiry interval. Within an accepted practice, unchanged sets can start without phone reachability, with fresh Watch physical confirmation and Start every time. New/changed setup needs explicit delivery. After relaunch, a quick phone review/Send can renew preparation without re-entering profile or stroke details. These are bounded coordination rules under cadence A, not persistent start authorization.

## First bounded implementation package

Author for foundational implementation: **Astra Extra High**, per the owner's subsequent explicit reasoning instruction. Earlier branding/accessibility presentation work used Astra High; architecture and independent review used Astra Extra High. Do not imply all prior coding used Extra High. Independent review stays separate and read-only. Preserve the existing `feature/guided-padel-setup` working tree and corrected branding manifest `1c7233b0b55ae2fdf29e8e48123b6caa5c6af6620e73ae4017f7c18f7f8450fe`.

Package 1 production scope is **only** new `Packages/PadelCore/Sources/PadelCore/PracticeSetupMessages.swift` and `PracticeSetupStore.swift`, maximum 2,500 changed production lines. New corresponding message/store test files, package-specific contract/evidence and a preserved new source manifest support it. Two risk domains: setup identity/metadata and bounded setup persistence. Do not edit existing app/Watch/transport/capture/raw-store/archive/export/deletion/signing/permission code in this package. The later packages remain bounded by the approved plan and require their focused contracts before edits.

Define and run tests first: literal typed wire payloads, both generations, finite enums, canonical digest, bounded payloads, exact duplicates, revisions/origin changes, atomic identity/revision bookkeeping, corrupt/missing/relaunch state, and preferences separated from ephemeral acceptance/confirmation. No message may request remote Start. Persistent setup state must be in its own bounded location and cannot modify existing recording directories or imply saved authorization. No unbounded replay history.

Run complete core regression, relevant builds/compilation and independent working-tree review before advancing to the transport package. Preserve every failed result. Update the final integration inventory/CI reference only within its separately bounded package; intermediate manifests remain explicitly private/local checkpoints, not hosted-CI proof.

## Remaining gates

Complete all approved packages and final iPhone/Watch builds, app/model/UI regression, actual premium UI inspection and new source evidence. Then obtain the repository-required explicit commit/push/draft-PR approval, exact-HEAD CI, independent committed-source review and applicable concrete device-installation approval. Observe physical setup handoff, local capture after phone disconnection, stop/save, verified phone receipt and export read-back before ball-contact collection. There is no shortcut from an App Store name reservation or signed build to real sensor/analysis success.
