# Guided Padel Setup — approved implementation plan

20 October 2026. Astra High implementation, following owner approval and Astra Extra High architecture review. Authority: PSL-SPEC-001 v1.1 S1-01/S1-02, the approved complete-training amendment and the owner's six-step setup amendment. This document precedes production edits.

## Baseline and boundary

Local branch `feature/guided-padel-setup` starts at `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`, stacked on unmerged `feature/watch-recording-storage`/draft PR2. Main remains `f21bfab`. No upstream exists for this new branch. No commit, push, PR, merge or physical replacement is authorized here. Xcode 27.0 (27A266a) and both OS27 SDKs were verified; commands explicitly select `/Applications/Xcode.app/Contents/Developer`.

Installed/launched physical build4 is the existing long-list preparation UI; no recording has been observed. See [build4 checkpoint](../testing/261020_Build4_Installation_Checkpoint_v1.0.md) and its private receipt54. Older Gate Card statements saying no installation occurred are historical. Build5 must be demonstrated in simulator before physical replacement.

Two Level3 domains: preparation authority/metadata and prestart lifecycle. At most seven production/config files and 2,500 changed production lines. Allowed: new WatchPreparationState.swift and WatchPreparationView.swift, WatchRecorderModel.swift, Watch ContentView.swift, phone ContentView.swift (guide only), project.pbxproj (build5), optional workflow manifest reference. Corresponding app-host/UI tests and these two documents are allowed. Root owns shared authority/status/evidence documents.

## Flow and authority

The Watch landing has one primary “Let’s Play” button. Every new set requires six ordered screens: acknowledge current racket arm and separately labelled usual handedness; explicitly confirm Watch physically on that arm; compare actual watchOS wrist/crown settings and confirm physical crown orientation; confirm secure comfortable fit; explicitly acknowledge one of all ten intended shot types; review summary and freshly confirm placement/fit before explicit Start. Back and Cancel are available. Saved values are suggestions, never confirmations. Invalid/missing raw preferences remain unselected; no right-arm or forehand coercion.

A value-type state machine owned privately by WatchRecorderModel is the sole preparation authority. Navigation cannot create acknowledgements. Each event checks its step and prerequisites. Arm/hand changes invalidate placement and downstream; settings changes invalidate orientation/fit/final; shot changes invalidate its acknowledgement and final confirmation. The first shot choice does not restart earlier steps. Background/inactive before capture invalidates physical confirmations and returns to the earliest incomplete step while retaining choices. Returning active re-reads settings and never grants confirmation.

Start synchronously refreshes settings, capability and storage, requires complete current state, consumes its single-use authorization and freezes production RecordingMetadata before any asynchronous workout work. No UI-supplied arm or handedness enters Start. Only preference values persist. Cancel/relaunch/new-set return to landing; terminal results remain until explicit new-set, including existing deletion-triggered new-set behavior. Preparation actions cannot mutate active or terminal recording identity, metadata, buffers, state, or pause/resume behavior. Recovery/retained recordings remain accessible from landing without setup. Physical placement is self-confirmed, never autodetected; no system setting mutations or private Settings links.

The iPhone “Let’s Play” guide mirrors all six steps and says preparation and Start occur on Watch without phone connectivity. No remote control or generative AI is added. Native controls, large text, progress, blue/yellow/white theme and clear workout/permission/capability explanations remain required.

## Non-goals and failure handling

No capture engine, hardware adapter, schema, protocol identifier, historical bytes, store, transport, export/deletion semantics, permission, entitlement or scoring changes. Mismatch, invalid preferences, stale settings, unavailable capability/storage, incomplete or reused authorization block Start. Simulator capability remains honestly blocked. Existing permission request/async error paths follow only after authorized Start. No physical reliability or merge-ready claim follows from simulator results.

## Verification and handoff

[The test contract](../testing/261020_Guided_Padel_Setup_Test_Contract_v1.0.md) defines production-path coverage. Author runs focused app-host checks after coordinating Xcode access; root runs final suites/builds and captures simulator flow after source freeze. Failures and exact commands remain under `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-GuidedSetup`, outside repo/Drive. CI, independent review and physical gates remain separate.

## Verified system help

Apple’s [watchOS27 orientation guide](https://support.apple.com/en-ge/guide/watch/apd0bf18f46b/27/watchos/27) confirms the manual Watch path Settings → General → Orientation (parent verified). Wizard mismatch help uses that path without deep links or changing system settings. Production source discovery for both new Watch files was verified by run01 app-host compilation.

## Approved stacked-PR CI scope amendment

Publication preflight found that the Foundation workflow's pull-request base filter omitted the planned stacked base `feature/watch-recording-storage`. Following independent review and root authorization after the final runtime suites, expand the existing seventh production/config file's allowed scope from the manifest reference to one additional base-filter entry. Add only that literal branch to the existing `main` and `chore/project-governance` list. Preserve workflow dispatch, permissions, commands, runner, checkout and timeouts. This makes the stacked PR eligible for its existing CI checks; it does not prove a remote CI run.

Before that edit, archive runtime-source manifest `1f93fc12aa93250fdc676ef02cf3f3129ea4b0d1591f72231faf16f42bb6abbf`. Regenerate its 57 entries afterward and verify that only the workflow hash changes, while every runtime source/test byte remains identical. Parse the YAML and assert all three intended base branches and workflow dispatch. Existing runtime evidence carries forward by that verified byte identity; no build, runtime rerun, remote action or installation is authorized by this amendment.
