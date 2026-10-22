# Owner-first O5 execution refinement v1.0

21 October 2026. Astra Extra High prepared the execution plan; independent GPT-6.1 Sol High found no missing constraint. Root ratifies this refinement within the already approved [first-build contract](261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md). This document does not release edits: O4b exact-source local acceptance must precede O5.

## Scope and bindings

Seven production files, at most2,400 changed lines against accepted O4b: new Watch `OwnerCaptureCoordinator.swift`; existing `WatchWorkoutDriver.swift`, `WatchRecordingServices.swift`, `WatchRecorderModel.swift`, `WatchPreparationState.swift`, `WatchPreparationView.swift`, and `ContentView.swift`. No Core, phone, motion adapter/engine, app entry, project, signing, schema or heart-rate acquisition changes. Tests first in new Watch app-host `OwnerCaptureAdmissionTests.swift` and only directly affected existing Watch app-host/main UI files.

- One retained service owns the coordinator and registers the counted owner-message handler before its sole connection activation, including background-only launch. Real namespace/lock checks and a durable deny-only witness prevent silent reconstruction or reset. An empty raw directory is not proof of a new owner namespace.
- The same MainActor admission generation advances before every authority, End, withdrawal, preparation or lifecycle worker hop. Publication uses checked off-main serialized stores. After every suspension, including the existing `workoutChanged` path, recheck fresh-only publication, exact store/context identity, checked authority revision, authorization/setup generations, fresh physical confirmation and resource closure. No suspension may intervene between final validation and actual engine admission. Duplicate/partial/failed IDs never start again.
- Permission/session/engine callbacks retain their immutable attempt/session generations. Old callbacks cannot rebind to a later practice. Preserve120-active-second raw capture and actual writer/source drain. Retain the native workout until observed `.ended`; a five-second shutdown timeout remains visibly blocked. Do not invent a sensor acknowledgement or conflate set Stop/Pause with practice End. O7 alone introduces practice-wide HR ownership.
- Phone-selected forehand/backhand and fresh brief wrist/crown/fit checks precede each explicit Watch-local Start. Relaunch, mutation, End and withdrawal retire preparation. An already authorized local capture survives phone loss; a remote message cannot Start.

## Runtime isolation and selection

Parse a DEBUG-only validated fixture UUID before eager `WatchApplicationDelegate.applicationDidFinishLaunching` initializes the service, and before recovery/model defaults access resources. Use canonical owned temporary recording/setup paths and an isolated preference suite, including recovery notice. Malformed explicit fixture identity fails closed. Fixture mode cannot activate real connectivity, Health authorization/recovery/session or motion acquisition. Production nil/default paths retain real adapters.

Each UI test gets a fresh UUID; every relaunch retains that same process fixture and never resets its namespace. App-host runner receives an isolated process identity before eager initialization; integration cases get separate child stores/preferences. Replace superseded six-step/all-stroke assertions with equivalent phone-acceptance, two-stroke and short physical-check coverage. Do not weaken simulator capability or local-Start restrictions.

Explicit O5 runtime exclusions: app-host `productionContainerPathsAcceptActualAppStorage()`, main UI `testLaunchPerformance()`, and generated Watch UI launch-test class. These are unexecuted obligations, not passes; O11 must address full-suite isolation. Before runtime, enumerate actual selected IDs and guard protected phone/Watch files and preferences; verify executed IDs and guards afterward. Never erase, uninstall, restore timestamps or repair protected data.

## Verification and release

Root captures tests-first failure, freezes source, runs meaningful publication/mutation/admission and old-callback/shutdown regressions, selected host/UI suites, both OS27 Release builds, protected-data guards and exact-source checks. Independent review and root acceptance precede the next package. Preserve every failure; diagnose before correction. No Git publication, physical replacement, merge or physical-readiness claim is authorized here.
