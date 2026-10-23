# O9 deletion prerequisite — proposed sequential split

22 October 2026. **ROOT RATIFIED after independent Sol PLAN CLEAR and accepted private tests. Tests-first execution active.** This document refines the approved O9 deletion scope without adding a feature. O8b source20 remains the accepted predecessor (105 inputs, manifest `d43a8af222ed45a0b2161ffd781f690d09051136afe7d7ca5fd2823e50b20926`).

## Verified conflict

`Watch/OwnerPracticeCoordinator.swift` owns two required paths excluded from O9's original eight-path allowlist:

1. `OwnerPracticeRecoveryReader.forEachCandidate` validates every used-ID witness/directory pair and opens `telemetry.json` before calling its visitor. Complete deletion must erase telemetry while retaining the minimal used-ID guard and empty reserved directory. Filtering in WatchRecordingServices cannot avoid that read; catching integrity errors would mask corruption.
2. Private `OwnerPracticeTelemetryWorker` retains exclusive `OwnerTelemetryStore` until explicit close. Normal End finalizes but does not close it. The DEBUG `closeForTesting` cancels/tasks/closes immediately and is not production observed native/query/writer shutdown.

## Proposed O9p slice

Retain the total 1,900 readable added-plus-removed production-line ceiling across O9p plus O9, measured against O8b20. No batch exceeds the eight-file limit.

O9p permits only two production paths:
- NEW already-planned `Packages/PadelCore/Sources/PadelCore/OwnerPracticeDeletion.swift`: the bounded checked deletion-proof portion needed by the reader; no full cleanup/connectivity feature in this slice.
- Existing `PadelStrokeLab Watch App/OwnerPracticeCoordinator.swift`: only deletion-aware candidate discovery and one narrowly scoped production drain/release operation plus necessary private-worker support. No unrelated O7 rewrite.

The reader may skip only an exact durably deleted practice authenticated by the planned deletion helper and checked minimal reserved witness/directory shape. Missing/corrupt telemetry without valid exact proof remains a hard integrity failure. No arbitrary boolean skip, broad catch, fabricated healthy payload or authority reset.

The scoped production operation must reuse actual End/endTask/publication ordering and observed native workout, HR/query/callback, recorder/source/writer closure before releasing telemetry ownership. Held/incomplete closure remains pending. Deleting a different historical practice must preserve unrelated current live ownership. Never reuse DEBUG closeForTesting as production closure.

## Tests and sequential gates

Before production, Astra authors only two new tests: Core and Watch `OwnerPracticeDeletionPrerequisiteTests.swift`. Tests prove healthy reopen of an exact deleted minimal directory/witness, deleted-ID nonreuse, absent/mismatched/corrupt proof rejection, actual targeted drain/release with held closure and no early removal, and unrelated-practice preservation. Independent Sol accepts exact tests; verification retains meaningful missing-interface red before bounded Astra Extra High implementation.

Full O9 Core/phone/Watch `OwnerPracticeDeletionTests.swift` drafts are preserved privately and not added to compiling targets until O9p acceptance; Swift compiles all target files even for a filtered run. No loss of drafted work and no temporary test suppression.

Freeze O9p source/tests, execute focused/affected regression, app-host/Release checks, reserved-container guards and separate independent source/evidence review before original O9 resumes. Original O9 eight paths remain as documented; its Core helper may then expand within the same total ceiling. No changes to frozen owner/setup wire/store/schema formats or competing store ownership. No code publication, device install or real Health data.

## Status

At09:04UTC the first Extra High author was interrupted after missing its save checkpoint; no production file or private production draft had been saved. No capacity/tool error was reported by that author. Root explicitly authorized a fresh compact **Astra High** author for this already-reviewed bounded implementation; independent Sol review and actual evidence requirements are unchanged. Work is incremental: first complete functional Core proof file and its3methods/7cases, then the Watch reader/scoped drain4methods/6cases. No placeholder counts as progress. Root model-capacity error is resolved; no technical/financial approval hold remains.

Independent Sol returned **PLAN CLEAR** for this exact sequential two-source/two-test split. The proof must bind operation identity, exact practice, owner/phone/Watch epochs, retained witness identity/digest and relevant deletion state under a checked descriptor-relative owned namespace. Pending intent is not completed cleanup. Drain must observe actual native/query/callback/source/writer and relevant publication completion before release. Root ratified the exact sequential slice after the owner reaffirmed continued blocker resolution. The prior director model-capacity error is resolved. No financial or technical approval hold remains for routine bounded gates; production follows verified missing-interface red. Physical testing remains NOT READY.

Private drafts are saved under the established evidence root's `O9-drafts/`, with all author edits stopped. Core prerequisite:103lines,3methods/7expanded cases, SHA `2fc21cf043278e2d6abe4b6205f6d5df9ce2eb615177c33e2b6a3d9791e0988d`; Watch prerequisite:167lines,4methods/6expanded cases, SHA `c557465b0f3891db9702294225cb32fa9d1f18470553538a559e5abd7ca08595`. Proposed interfaces are checked `OwnerPracticeDeletionProof.prepare(base:header:operationID:)` with retained `complete()`/`cancel()`, `isCompleted(base:practiceID:)`, and scoped `OwnerPracticeCoordinator.prepareForDeletion(practiceID:) async throws`. The private Core full-O9 draft remains242lines/6methods/10cases, SHA `9f8a3081f4fd26fb73e17b8cf068d4e94546848bca57e85c7c10257753cb1e94`. The exact reviewed drafts are now mechanically copied to the two approved test paths after SHA verification. O9p01 freezes107inputs with all105 O8b inputs unchanged and zero production delta: manifest `6e45a713b7ff44c57340e6be94396b39ed8c4556ce5151ccf31389d2c3d729ff`, archive `f46d7df14a964f3f8c17434fbbc411fb4fd4a3cd1082067715dc836a0751edbd`. Missing-interface red02 Core exit1/4.456s and03 Watch app exit65/8.865s are retained. Director inspected all substantive diagnostics: only planned proof/drain interfaces are missing; all107inputs remain unchanged. Fresh Astra Extra High is now released only to the approved two production paths. No runtime pass is claimed.

Separate Sol independently rehashed and read all270 prerequisite test lines plus actual shared fixtures: **PRIVATE DRAFTS ACCEPTED for director ratification/tests-first placement**, with no concrete adequacy/harness blocker. This does not authorize production. Reader proof must use the checked implementation, never caller-supplied Boolean authority. Scope ratification and exact repository placement/freeze are complete. Meaningful missing-interface red is verified; bounded implementation/evidence gates remain. No additional director permission is required for routine steps inside this ratified slice.

