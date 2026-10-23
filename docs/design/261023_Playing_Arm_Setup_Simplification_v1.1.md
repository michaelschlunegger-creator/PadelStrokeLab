# Playing-arm setup simplification v1.1

23 October 2026, Asia/Dubai. Owner-approved presentation amendment to
[v1.0](261023_Playing_Arm_Setup_Correction_v1.0.md).
Baseline: `feature/guided-padel-setup`,
`e38f84fa8aa8e65426b1e52317c2a40ea13c4c20`.

## Customer problem and decision

The owner showed the lengthy wrist/crown/fit instructions after answering that
the Watch was already on the racket wrist. Those instructions suggest unnecessary
work. The owner directs: keep the flow logical and simple for the player.

Ask the same two explicit questions. Once both are answered:

- Matching sides: show only the existing short placement confirmation in the
  guidance area. Hide move/configuration/fit instructions and its repeated footer.
- Different sides: retain the move instruction and existing phone-led system
  wrist/crown/fit guidance.

Neither answer is assumed. A self-reported wrist is not sensor verification.
The existing Watch's fresh placement/orientation/fit checks and local Start remain
unchanged. The general Start-on-Watch notice elsewhere on the phone remains.

## Bounded scope and test contract

Level 2 UI presentation only. Allowed code: `PracticeSetupView.swift` and the
existing `OwnerPracticeSetupUITests.swift`. Documentation/current source identity
may advance. All Watch/Core/model/Health/capture/transport/storage/build/workflow
inputs remain unchanged. No physical replacement, merge or release is part of
this amendment.

Define the regression before changing production. The existing four-pairing test
must require the short confirmation and absence of detailed instructions for
both matching cases; require existing move/configuration/fit content for both
different-side cases; retain unanswered/reset and preparation assertions. Run
this affected method without retries, affected builds, source checks and
independent exact-commit review. Full exact-HEAD CI remains required before gate
clearance; earlier production-input evidence cannot be relabelled for this patch.

Acceptance: both match cases are brief, both move cases remain actionable,
preparation gating and all Watch safeguards are unchanged, and the user-visible
phone simulator runs the revised source. Physical testing is a separate gate.
