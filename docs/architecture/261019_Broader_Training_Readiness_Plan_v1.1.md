# Complete first-training workflows and shot types — v1.1

19 October 2026, Asia/Dubai. **APPROVED SCOPE** under the explicit owner reply “Yes, full training workflow and shot types” after the linked v1.0 plan. The owner reinforced use of Astra. Astra Extra High reviewed the plan and returned PROCEED with the refinements recorded here before production changes. v1.0 is historical; its pending-scope wording no longer applies. [Product authority](../PRODUCT_AUTHORITY.md) records the amendment without modifying the immutable PSL-SPEC-001v1.1 snapshot.

## Starting authority and purpose

Branch `feature/watch-recording-storage`, local/remote starting HEAD `80759910fa356e03c2b61a46a5ae554c19d23978`, base `ee15c0ef86c99064bb1295c7550fba1daea66a3c`; separate foundation/main unchanged, draft PR2 open. User-approved dependent branch/publication workflow remains in effect; no merge/release approval. Xcode27.0(27A266a), Swift6.4 and both OS27 SDKs were reverified before source changes. Existing local build3 evidence remains a historical baseline once code changes.

Purpose: owner-led real training-data collection on iPhone/Watch for all supported manually intended shot types, preserving the complete setup/record/pause/resume/save/recover/offline-transfer/review/labels/export/delete workflow. Watch stays on the playing arm. Keep the premium blue/yellow/white native theme, 120-active-second capture limit, no paid coach requirement and truthful uncertainty. Selection is manual intent, not automatic shot recognition or a hit-quality result. Social/AI/cloud/booking/full-match analysis remain later roadmap work.

## Allowed bounded package

Astra High implementation; five production files, at most2500 changed lines and two Level3 domains: experimental metadata/provenance and session-setup integrity.

1. New `Packages/PadelCore/Sources/PadelCore/RecordingDrill.swift`.
2. `PadelStrokeLab Watch App/WatchRecorderModel.swift`.
3. `PadelStrokeLab Watch App/ContentView.swift`.
4. `PadelStrokeLab/ContentView.swift`.
5. `PadelStrokeLab/RecordingDetailView.swift`.

Allowed tests: a new core RecordingDrillTests file; Watch existing app-host/UI test files; phone existing RecordingLibraryTests and UI flow test file. Add a narrowly scoped test fixture/helper only if required and report it. Parent owns project build4 (all12 existing build-number settings), workflow manifest reference, source manifest, documentation and final integration evidence.

Forbidden: PracticeDrill or historical foundation archive changes; recording/annotation schemas/codecs; sensor engine, clocks/buffering/store; workout/motion adapters; connectivity/receipts/deletion semantics; permissions/entitlements; signing/bundle/OS changes; fake hardware/UI recording launch modes; unrelated production edits.

## Behavior contract

Stable raw values: `forehandGroundstroke`, `backhandGroundstroke`, `forehandVolley`, `backhandVolley`, `serve`, `lob`, `bandeja`, `vibora`, `smash`, `otherUnclassified`. Supply readable titles separately. Every NEW recording, including forehands, uses protocol `owner-manual-training-logger-1`. Existing raw metadata and `owner-forehand-logger-1` protocols remain untouched.

New/missing persisted choice displays Choose shot type. Unknown saved choice displays Saved shot type unavailable—choose again; neither silently becomes forehand or Other. Valid previous choices may persist; placement confirmation never persists. Guard selection mutation in the model, only in Ready. All starting/recording/pausing/paused/resuming/stopping and terminal states reject shot changes until Prepare new set.

Freeze validated selection synchronously at Start before asynchronous workout/capture; use that exact selection for immutable metadata and active/terminal display. Clear the captured snapshot only on Prepare new set. Existing canPrepare includes terminal states and must not be used as the shot-picker edit guard. Changes to choice, playing arm, handedness or actual wrist/crown require fresh arm confirmation; launch and new set also clear it. Retain Start's real settings/capability recheck and unsupported-simulator block.

Use a native navigation-link picker with readable wrapping choices, visible title, accessibility identifier/value and Intended shot type. Record one type per short set guidance. Other / unclassified deliberately leaves intended type unspecified; it is not a detected classification, mixed-match collection protocol, nonStroke/airSwing or uncertain-contact label.

Phone details show a readable Intended shot type title, exact stored raw value and protocol. Recognize legacy forehand without migration. Unknown historical/future raw strings stay visible verbatim as unrecognized recorded values, never coerced to Other. The phone guide lists supported choices and generic recording workflow, retains the initial one-attempt collection step for reliable matching, and removes contradictory Other strokes can wait wording. All motion is recorded; no automatic quality inference.

Factor synchronous metadata creation into a method actually called by Start, independently testable without launching workouts or faking capture. Preserve immutable returned metadata after subsequent preparation changes. Keep ordinary real UserDefaults persistence with isolated test defaults; no fake supported sensor mode or new public testing flags.

## Acceptance, testing and physical entry

The [test contract](../testing/261019_Complete_Training_Test_Contract_v1.0.md) precedes implementation and covers vocabulary, metadata construction, all state/persistence guards, actual ten-type store/archive/import roundtrips, non-forehand and legacy phone review/labels/export preservation, unknown metadata compatibility, real Watch picker flows and generic phone accessibility/navigation flows. Existing assertions remain.

After source freeze, run full affected core/phone/Watch suites, both Release simulator builds and signed physical build4, verify source/signatures/profiles, then publish for exact-HEAD CI and a new independent committed-code review. Preserve every failed command/result; no assertion weakening or automatic retry. Evidence must identify exact source. Installation remains on hold until pre-install checks clear.

Then install/launch each physical app separately and perform one action at a time: select a non-forehand type for a controlled air swing; verify real counts/save, phone receipt, exact selected type/new protocol and export read-back; prepare a different type and confirm placement resets. Only after this end-to-end dry run collect real contacts. Permission, wrist-lowered/background, offline transfer, pause/resume, interruption/recovery/deletion and battery checks remain explicit physical observations. No hardware, per-type quality or release claim follows from simulator evidence. G7 precedes merge readiness; user approval still controls merge/release.
