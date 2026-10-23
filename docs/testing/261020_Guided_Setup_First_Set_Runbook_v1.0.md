# Guided setup — first physical set runbook v1.0

20 October 2026. Applies to the owner-approved six-step wizard on `feature/guided-padel-setup`, version 1.0/build 5. This is a preparation/test runbook, not a claim of physical verification. The installed devices currently retain logger build 4. The [source manifest](261020_Guided_Padel_Setup_Code_State.sha256) and [local evidence](261020_Guided_Padel_Setup_Local_Evidence_v1.0.md) identify the working-tree package; record the actual committed HEAD before physical testing.

## Entry conditions

Complete required local checks, publication approval, exact-HEAD CI and committed-source independent review first. Show the owner the simulator UI before replacement. Record the applicable owner authorization for replacement installation and verify that it covers this build; publication approval and displaying the simulator do not themselves authorize installation. Before any device action, recheck device reachability/signing, install and query version/build on iPhone and Watch separately, then observe both launches. Do not infer Watch installation from an embedded bundle. No merge, release or expense is authorized by this runbook.

Use the owner's iPhone 15 Pro and Watch Ultra 2; re-query their current OS versions. End other workouts before capture. Record system permission outcomes and failures. Keep device identifiers, personal recordings and raw logs private. Coordinator delivers one observable physical action at a time and records the result before continuing.

## Preparation before every new recording set

1. On Watch, tap **Let’s Play**. Expected: **STEP 1 OF 6 — Your racket hand**. Choose/acknowledge the hand holding the racket for this set; usual handedness is separately labelled metadata. A saved suggestion is not confirmation.
2. At **Watch on racket arm**, physically move the Watch to the racket arm if needed. If removal locks the Watch, unlock it and return to the app, then explicitly confirm placement. The app cannot detect which arm is actually wearing it.
3. At **Watch orientation**, compare required arm with the displayed watchOS wrist/crown settings. If mismatched, use Watch **Settings → General → Orientation**, set the actual wrist/crown orientation and return. Repeat any placement check that reappears after leaving the app, then refresh/reconfirm the displayed values; changed settings require a fresh acknowledgement. Do not proceed through an unresolved mismatch.
4. At **A comfortable fit**, secure the strap so the Watch stays in place during a swing without being too tight; explicitly confirm. Fit is the player's observation.
5. At **Your shot type**, choose/acknowledge **Forehand groundstroke** for the first owner test. Use one intended shot type per short set. Shot choice is manual drill metadata, not automatic recognition.
6. At **Ready for this set?**, review arm, usual hand, orientation and intended shot, freshly confirm placement/fit, then explicitly start recording. Expected on supported hardware: the permission/start flow and real live stream counters. A capability/permission/storage blocker is an observed failure to diagnose; do not repeatedly retry. The simulator correctly blocks sensor capture.

Back/Cancel must remain available. If the app leaves active foreground before capture, physical confirmations must be renewed. Every subsequent new set repeats the wizard; saved preferences may remain suggestions. Pause/Resume stays within the existing set and does not initiate another preparation flow. Preparation must not reset an active/paused recording or hide retained/recovery data.

## First dry run and court gate

After observing Recording and increasing accelerometer/device-motion counts, make one controlled air swing without touching the screen, then stop/save. Observe the actual local-save/verification status. The existing limit is 120 active seconds, excluding pauses; accepted live counts and durable saved chunks have different meanings. Do not claim the final sensor tail is verified without inspection.

Retrieve the recording on iPhone, verify receipt/status and metadata, review the two retained streams and export the session. Verify the exported artifact and correspondence to the observed set. Use uncertain/self-reference labels honestly; a dry air swing is not a ball-contact quality label. Record observed result/evidence at each action. No court contacts until this end-to-end dry run is observed successfully.

Then follow the existing [physical logger runbook](261019_Physical_Shot_Logger_Runbook_v1.0.md) for a controlled forehand contact per recording, owner labels and separate failure/recovery checks. Its older build/source preflight and flat-list preparation/start instructions are historical. This runbook’s six-step setup and actual committed build/source identity supersede those instructions for build 5; apply the older runbook’s recording/review/recovery checks after the current setup. The original recording, persistence, transport/export contracts remain unchanged. Test pause/resume, lowered wrist/background, phone absent/later transfer, interrupted recovery, permission denial and deletion separately after initial success.

A successful dry run proves one observed logger workflow. It does not prove clean-contact prediction, general-player accuracy, battery reliability, long-session operation or release readiness.
