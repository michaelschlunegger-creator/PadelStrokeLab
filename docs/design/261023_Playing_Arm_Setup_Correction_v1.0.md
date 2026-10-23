# Phone-led playing-arm setup correction v1.0

23 October 2026, Asia/Dubai. Owner-approved bounded correction. Baseline:
`feature/guided-padel-setup`, `9fbb37673bebaf607f5f4862ec1909f5124f1fdd`.

## Problem and owner decision

The live walkthrough exposed confusing duplicate ordinary questions: racket arm
and usual playing hand. The owner explicitly approved correcting this immediately.
Ask which hand holds the racket and which wrist currently wears the Watch first.
A common case is right racket hand and left Watch wrist, but neither answer may
be treated as confirmed merely because it is common or saved.

## Approved flow

1. On iPhone, explicitly confirm the racket hand: Left or Right.
2. On iPhone, explicitly report the currently worn Watch wrist: Left or Right.
3. Once both are known, show the applicable direction:
   - Right racket / left Watch: **Move your Watch to your right wrist.**
   - Left racket / right Watch: **Move your Watch to your left wrist.**
   - Matching sides: acknowledge the reported playing-arm placement.
4. Guide the physical move, checking the system wrist/crown configuration, and
   a snug comfortable fit mainly on the phone. Crown side must match actual wear;
   it must not be guessed from handedness.
5. Retain manual forehand/backhand selection and existing phone preparation.
6. Retain the Watch's fresh physical placement, orientation and fit confirmations
   before every set, followed by the existing explicit local Start.

Physical wear, reported wear, configured wrist, and racket hand are distinct.
The app must not claim to sense or verify physical placement from a phone answer.
Phone guidance does not establish Watch admission or remotely start capture.

## Scope and invariants

This is Level 2 presentation/local guidance over unchanged Level 3 safeguards.
At most three production files: phone setup view; matching in-app practice-guide
copy in the phone home view; DEBUG offline-fixture seeding only if necessary for
regression evidence. The Watch preparation view remains unchanged.
Existing relevant UI tests and documentation may change. No Core/model authority,
transport, capture, Health, persistence schema, metadata format, project settings,
build number, new sensors, recognition, guests, or dependencies may change.

For publication, the current CI checksum index may advance to the exact frozen
inputs, with a new dated immutable copy retained. Preserve the same 115 input paths
and the unchanged workflow; this is source-identity metadata, not a waived gate.

Answers are transient and require explicit review on a new screen entry. A racket
hand change invalidates the current-wrist answer; a wrist change recomputes the
directions. Missing answers keep the phone preparation action unavailable, in
addition to all its existing conditions. Do not lose an explicit choice to a load
race or weaken any Watch check.

For a first unsaved setup, the explicit racket answer can initialize both existing
handedness values. Preserve saved usual handedness. If it differs from the newly
confirmed racket hand, make that saved difference visible with an explicit way to
keep or correct it. Do not silently overwrite it or hide a wrong handedness default.

## Test contract and gates

Define regression tests before production changes. Cover unanswered startup; all
four side pairings; changes/reset/re-entry; saved left/right handedness differences;
explicit correction; existing consent/offline behavior; largest Dynamic Type in
portrait and landscape; and existing Watch fresh-confirmation/orientation/Start
safeguards. Use Xcode 27 and iOS/watchOS 27 only, isolated test fixtures, retained
results, and no automatic retries. Run affected builds and independent review.

Prior build-7 CI/install evidence remains evidence of the baseline, not this patch.
Simulator demonstrations cannot validate physical sensors, wear or background use.
No physical replacement, merge or release is part of this UX correction package.
Any subsequent publication and device replacement must satisfy their current gates.
