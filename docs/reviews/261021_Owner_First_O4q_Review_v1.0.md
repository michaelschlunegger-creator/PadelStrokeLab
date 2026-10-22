# Owner-first O4q independent implementation review v1.0

21 October 2026. GPT-6.1 Sol / High, selected for independent non-Astra review of the approved bounded persistence and authority-ordering package. Review only; no production/test/configuration edits, builds, tests, Git or device actions. This report is the sole authorized write.

## Verdict

**BLOCKED — local O4q acceptance only.** One source invariant defect and a separate unresolved full-suite failure remain. This is not formal committed-HEAD G6 review, merge approval or physical readiness. O4b remains held.

## Exact reviewed state

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; root-reconciled branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, with intentional unpublished work.

- Ratified [amendment](../testing/261021_Owner_First_O4q_Lifecycle_Amendment_v1.0.md): SHA-256 `d46c098f1387442ee669fa8a629927fa5b70d420be913be1888bfa16fef74eb6`.
- [82-input source manifest](../testing/261021_Owner_First_O4q_Source_v1.0.sha256): `05598704c9e6c41aeb92faa0e3bac9c055e04074c3c5607aa56967937d54405e`.
- Private `Checkpoints/04q-o4q-source.tar`: `caa5b2cef7b5b61bdaf4e7b65caec3b9d4894d65db1e7c9a691de027dd379685`.

Independently verified all82 current/archive payloads. Against accepted O4a, only `PracticeSetupChannel.swift` and its existing matching test file differ; production is +109/-11,120 changed lines within cap200. Other80 inputs remain exact.

## Blocking source finding

**[P2] Enforce distinct local End and retained wire identities.** In `Packages/PadelCore/Sources/PadelCore/PracticeSetupChannel.swift:256–262`, `queueRequestedEnd()` returns an existing exact-practice retirement without checking its mutation ID against the local `endRequestID`. Only the newly generated command branch enforces inequality.

Concrete public-API sequence after enrollment and `beginPhonePractice(practiceID:p, preparationID:s, owner:owner)`:

1. `requestPhoneEnd(practiceID:p, requestID:e)`.
2. `request(.retirePractice(from:owner, practiceID:p, mutationID:e))`.
3. `queueRequestedEnd()` returns the retained command whose wire ID equals local End ID `e`.

The reverse order also succeeds because `requestPhoneEnd()` at241–251 does not reject the existing wire ID. After an intervening verified transition makes retirement obsolete, `resolveObsoleteIntent(replacement:)` at320 onward likewise accepts a replacement using `e`. These admitted paths contradict the ratified explicit identity separation.

Required correction: consistently enforce this invariant at lifecycle/intent changes and persisted-journal validation without rewriting an occupied command. Add regressions for direct request, obsolete replacement, retirement-before-latch (including dispatched intent), and invalid persisted/reopened alias state. Rejections must preserve the retained intent and lifecycle. No broader authority redesign is requested.

No additional concrete source blocker was found in the reviewed bounded diff.

## Evidence and remaining gates

Independently checked [local evidence](../testing/261021_Owner_First_O4q_Local_Evidence_v1.0.md), SHA `6f253683420b9294b85cf7a8bbfdbb63e58a31cb1b99c1fd9c26ee577939c041`, and all8 private evidence hashes; manifest SHA `24b6cafe4b4bd9974d9d2ebc424356fa4d4807c9acc0cbf2861f12e83f571240`.

- Preserved tests-first missing-API compilation failure; focused channel47 tests/2 suites PASS,253.445s.
- Fresh full Core run04 **FAIL**:260 tests/20 suites,1 issue; runner112.837s, process exit1/117.853s. `RecordingLocalCopiesTests/deletionWaitsForImportThenWithholdsAckAndPreventsResurrection()` failed at line95: `atReceipt.wait(timeout: .now() + 10)` timed out. Both channel suites passed. The full-suite failure is a separate unresolved gate blocker; cause is UNKNOWN. No retry, harmlessness claim or attribution to O4q is justified.
- Affected app-host/bootstrap regression and both current OS27 Release builds: **NOT RUN**. Later CI, formal committed review, physical and merge gates remain open.

Next: authorized Astra correction plus regression coverage, diagnosis of the full-suite failure, then a new freeze and affected verification before independent review and director acceptance.
