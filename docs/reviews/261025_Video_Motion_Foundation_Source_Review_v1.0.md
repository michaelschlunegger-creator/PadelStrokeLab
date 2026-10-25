# Scoped video/motion foundation source review

25 October 2026. Independent non-author `gpt-6.1-sol` High reviewer
`video_motion_architecture_review`, review only, no file modifications or builds.
Frozen commit: `c2c7089`, packages A0/A/B only; C/E working edits excluded.
This is preliminary integration review, not G6, merge or physical clearance.

One actionable blocker: `VideoMotionStore.publish` requires the original exact
capture authority. Normal Watch End retires the practice and advances that
authority revision. Therefore retained shot edits and late reconciliation would
fail with stale authority, despite the same owner still allowing collection.

Correction contract A1: preserve exact-original `create`/live `publish`. Add
separate retained update/read permission using the current OwnerChannelSnapshot:

- Same owner, both installation epochs and current policy digest.
- Collection allowed, revision and consent generation at least the captured
  values, and the same withdrawal barrier.
- No current motion-access block; existing practice tombstone/CAS remain binding.
- Label edits do not require HR permission and ignore ordinary admission/replay
  guards created by normal End. HR-bearing export keeps separate existing checks.

G/H must obtain fresh channel state and check pending ingress/deletion state at
publication. A stored identity alone is not current authority. Live acquisition
must never use the retained-update path or regain a retired preparation.

Tests use real authority mutations/resolution: normal retirement/advance and HR
toggle allow retained labels but deny live publish; withdrawal and later
reconsent deny old bindings; pending motion restriction, foreign owner/epochs,
policy mismatch and practice tombstone deny. Binding/raw bytes stay unchanged.

No additional blocking A0/B algorithm/reducer finding was reported. Checked
bootstrap recovery/cleanup remains a G prerequisite before hardware exposure.
Root schedules A1 after E's pending test contract is implemented, because SwiftPM
compiles all test files and the new E symbols are not present yet. C/E may proceed
without exposing capture; A1 must pass before G/H and real collection.
