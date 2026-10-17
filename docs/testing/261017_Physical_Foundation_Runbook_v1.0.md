# Physical foundation runbook — 17 October 2026

**Status: prepared; physical installation and observations NOT RUN.** Model: Astra, High reasoning, for bounded preparation and testing of the approved foundation. This is an installation/UI smoke protocol, not an on-court recording protocol or proof of sensor feasibility.

## Source and scope

- Repository: `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`.
- Preparation baseline: `chore/project-governance`, HEAD `9f91550755eb5d317a6603ebb0ebf1eab19bcaaa`; base `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`. Local upstream matched this HEAD at preparation.
- [Draft PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1) contains the independent review of that HEAD: no blocking code defect identified; verdict **BLOCKED** because clean CI and relevant physical evidence were absent. The older G6 NOT RUN entry in the Gate Card predates that review.
- Before execution, record the actual current committed HEAD, clean worktree, upstream and PR status. Adding this runbook or CI creates a new HEAD: reconcile its scope and refresh independent review; do not silently carry the previous verdict forward.
- Existing application/test/configuration identity: [22-file source manifest](261016_Foundation_Code_State.sha256), manifest SHA-256 `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`. All 22 entries matched during preparation. Record verification again against the exact physical build source.
- Authority: [Product Authority](../PRODUCT_AUTHORITY.md), PSL-SPEC-001 v1.1 sections 2, 3, 6.4 and 7; [foundation architecture](../architecture/001-prototype-foundation.md); [test contract](FOUNDATION_TEST_CONTRACT.md).
- Only the existing preparation screens are in scope. This does not complete S1-01, S1-05, WP1 or any recording/transfer milestone. Reference-label names are displayed; this build does not collect labels or record strokes.

## Entry gates and preflight evidence

| Check | Preparation observation / execution gate |
|---|---|
| Approved platform | Xcode 27.0 (27A266a), iOS/watchOS 27 SDKs verified locally. Every local command must use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Xcode/SDK 26.5 cannot produce project evidence. |
| Physical phone | iPhone 15 Pro, iOS **27.2 (24B5099f)**, observed in the Mac device inventory on 17 October. Recheck if updated. |
| Physical Watch | Apple Watch Ultra 2, watchOS **27.0 (24R364)**, observed in the Mac device inventory on 17 October. Recheck if updated. |
| Device availability | Both appeared available over the network in Xcode's inventory; Mac trust/pairing was reported. A disconnected development tunnel means immediate installation readiness remains unverified. Mac trust does **not** prove iPhone–Watch companion pairing. |
| Signing | Parent preflight built both Debug schemes successfully with existing signing. Both app signatures passed strict verification. Embedded profiles include the respective observed devices, allow debugging and expire 9 August 2027. No provisioning updates were requested. Do not publish profile contents, device identifiers or certificate/account names. |
| App identity | Version **1.0**, build **1**, minimum OS **27.0** on both apps. iPhone bundle `com.michaelschlunegger.PadelStrokeLab`; Watch bundle `com.michaelschlunegger.PadelStrokeLab.watchkitapp`; Watch companion identifier matches the phone. The phone build includes the Watch app. Preserve these settings and the existing signing team. |
| Local automated evidence | [Existing foundation results](261016_Foundation_Local_Evidence_v1.0.md): 29 core tests, both Release simulator builds and both existing simulator suites passed. App tests provide template/launch coverage only. They do not replace this protocol. |
| CI | Require a successful **Foundation checks** run against the exact committed source under test. Record run URL and checked-out SHA; preserve failed runs. New CI configuration is not evidence that CI has passed. |
| Independent review | After CI/preparation changes, review exact committed HEAD, review only. Resolve any implementation/CI blockers before installation. A verdict still blocked solely on missing physical evidence is not permission to call the branch merge-ready; complete this protocol and reconcile the final verdict afterward. |
| Human/device readiness | Before the first device install, establish that the phone and Watch are nearby, unlocked, sufficiently charged and available for testing; confirm Xcode recognizes the intended physical destination and that required trust/Developer Mode setup is complete. Resolve any actual setup prompt one action at a time. No assumed permission approval. |

Local signed-build logs and result bundles are retained outside the repository at `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-Physical-Foundation/`: `Logs/iPhone-signing-preflight.log`, `Logs/watch-signing-preflight.log`, `Results/iPhone-Signing-Preflight.xcresult`, and `Results/Watch-Signing-Preflight.xcresult`. These establish signed build success, not device installation or launch. Preserve all failures and subsequent attempts as separate evidence.

## Execution method

The operator gives the owner **one observable action at a time** using “Step X – Action / How / Expected result”, then waits for the observation. End device instructions with “Confirm when done, and I’ll give the next step.” When copied output is needed, ask “Paste the copied output here.” Do not send the whole checklist as simultaneous instructions.

Use the source checkout above, `PadelStrokeLab.xcodeproj`, Debug configuration and the existing schemes below. Keep build/results outside the checkout. A device install may replace an earlier development build; retain its data unless a separately approved reset is required. Do not uninstall to manufacture a clean result. Any signing, entitlement, bundle-ID, production-source or build-setting change stops the run and requires affected gates again.

Record each row separately as **VERIFIED**, **CONTRADICTED**, **UNKNOWN** or **BLOCKED**, with actual observation, time and evidence reference. Expected text below comes from committed production views and `PadelCore` label definitions.

### Installation and phone observations

| ID | Single action / how | Expected observable result |
|---|---|---|
| P01 | On the paired iPhone, open Apple's Watch app and inspect the current Watch under All Watches. | The intended Watch Ultra 2 is shown as its paired companion. Record a sanitized observation; Mac device trust alone is insufficient. |
| P02 | In Xcode select scheme **PadelStrokeLab** and the physical iPhone 15 Pro destination; inspect the selection. | Physical phone selected, no simulator; existing signing identity and app identifier unchanged. Record the exact configuration. |
| P03 | Use Xcode **Command+R** for the phone scheme. | Build/install/launch succeeds on that phone and the app shows **PadelStrokeLab**. Retain the Xcode run outcome. If trust, Developer Mode or signing blocks it, stop and address that actual blocker separately. |
| P04 | Inspect the top of the phone preparation screen. | **Your personal practice lab**, **First drill**, **Forehand groundstroke**, and **Watch on your playing arm** appear. Text is readable on this phone at the recorded text size. |
| P05 | Scroll through **Reference labels**. | All five names appear in order: **Clean contact**, **Mishit**, **Uncertain**, **Air swing**, **Other movement**. The explanatory text distinguishes contact from ball outcome and allows uncertainty. These are displayed reference categories, not recording or label-entry controls. |
| P06 | Scroll to **This build**. | **Practice preparation** and **Motion recording is not available yet. No hits are recorded or scored in this build.** appear. No recording control or score is present. |
| P07 | Stop the phone run in Xcode. | The tested debug process terminates. Record that termination, rather than treating backgrounding as a fresh launch. |
| P08 | Open PadelStrokeLab from the phone's app icon. | The same preparation screen launches outside the debugger without a crash. No Health or Motion permission request is expected anywhere in this foundation run. |

### Watch observations

Watch installation is a separate check even if the phone install delivers its embedded Watch app. The app itself has no WatchConnectivity transport; installation/pairing success must never be reported as verified app-to-app transfer.

| ID | Single action / how | Expected observable result |
|---|---|---|
| W01 | In Xcode select **PadelStrokeLab Watch App** and the intended physical Watch Ultra 2 destination; inspect the selection. | A physical Watch destination associated with the intended companion is selected; no simulator and no signing changes. |
| W02 | Use Xcode **Command+R** for the Watch scheme. | Watch build/install/launch succeeds and **Practice setup** appears on the actual Watch. Retain the Xcode run outcome independently of the phone outcome. |
| W03 | Inspect the Watch screen, scrolling with the Digital Crown if required. | **Playing arm**, picker **Arm**, toggle **Watch is on this arm**, **First drill**, **Forehand groundstroke**, and **Preparation only. Recording is not available in this build.** are readable. Fresh process state shows **Check your Watch placement** and confirmation off. A previous saved arm may be selected; **Right** is only the default when no arm preference exists. |
| W04 | Choose **Left** in **Arm**. | The selected arm is Left. If this changed the arm, confirmation is off and **Check your Watch placement** appears. |
| W05 | With the Watch actually on the selected left arm, enable **Watch is on this arm**. | Toggle is on and **Arm confirmed** appears. If the Watch must be moved, give moving it as a separate preceding action. This UI exercise does not establish which arm is the owner's playing arm. |
| W06 | Change **Arm** to **Right**. | Selection becomes Right; confirmation immediately clears and **Check your Watch placement** replaces **Arm confirmed**. |
| W07 | With the Watch on the selected right arm, enable **Watch is on this arm**. | **Arm confirmed** appears. Handle any Watch relocation as a separate action. |
| W08 | Change **Arm** back to **Left**. | Confirmation clears again. This checks both directions of the reset rather than assuming symmetry. |
| W09 | Select the owner's actual playing/racket arm. | Correct arm is selected; record Left or Right without inferring it from handedness or prior preference. If already selected, do not claim a change-triggered reset occurred. |
| W10 | Place the Watch on that playing arm if it is not already there. | Owner confirms physical placement. This is a preparation observation, not sensor/orientation validation. |
| W11 | Enable **Watch is on this arm**. | **Arm confirmed** appears for the actual playing arm. |
| W12 | Stop the Watch run in Xcode. | Debug process terminates; record this. Merely lowering the wrist or returning to the watch face does not prove process termination. |
| W13 | Open PadelStrokeLab from the Watch's app list. | Arm selection persists via `@AppStorage("practice.playingArm")`; confirmation is **off** and **Check your Watch placement** returns because confirmation is `@State`, initialized false. Do not expect confirmation to persist across a fresh process. |
| W14 | Confirm the Watch is still on the selected arm by enabling **Watch is on this arm** again. | **Arm confirmed** appears and controls remain operable on the physical Watch. No motion recording, workout or permission request starts. |

The Watch arm preference is local to the Watch. There is no requirement or implementation for the phone to mirror changes. Ordinary background/foreground behavior may retain the in-memory confirmation while the process remains alive; do not record that as a persistence failure. There is no session lifecycle in this foundation, so per-session confirmation is not yet implemented.

### Readability and accessibility smoke checks

After the functional sequence, inspect the screens on both devices at their current text sizes and record any clipping, unreachable controls, ambiguous labels or awkward Crown/touch operation. When testing a different text size or VoiceOver, give each settings change as a separate action, record the original setting and restore it afterward. Any such check must have an actual observation; unperformed accessibility checks remain UNKNOWN. This bounded smoke run does not certify comprehensive accessibility, battery life, background reliability or on-court usability.

## Evidence record and rubric

Create a dated result record in `docs/testing/` after execution and link it from the current Gate Card/PR. Do not fill observations from expected outcomes. Minimum fields:

| Field | Required value |
|---|---|
| Identity | Date/time/timezone, operator role, repository, branch, exact committed HEAD, upstream/remote verification, source-manifest result, clean/changed worktree scope. |
| Gates | CI run URL and tested SHA; independent review URL/verdict/remaining conditions; any explicit approved deviation. |
| Build | Xcode and SDK versions, physical schemes/destinations, Debug configuration, app version/build, bundle IDs, signing verification summary, signed build/install timestamps and result references. Version 1.0/build 1 alone does not identify the source. |
| Hardware | iPhone/Watch models and exact OS versions/builds; companion-pairing observation; current Watch arm/placement; text sizes and relevant UI settings. Exclude serial numbers and UDIDs. |
| Each test | P01–P08 and W01–W14: expected result, actual result, status, timestamp and sanitized screenshot/photo or log/result reference. Mark irrelevant conditional relocation steps explicitly not required, with reason. |
| Failures | Preserve first failed attempt, exact visible error, scope and follow-up evidence. Do not relabel a failure as passed because a later attempt succeeded. |
| Limits | Identify unperformed checks, remaining bugs, installation limitations and all unimplemented capabilities. |

**VERIFIED** means the expected behavior was directly observed for the identified build and evidence is retained. **CONTRADICTED** means the observed result differs. **UNKNOWN** means evidence is absent or inconclusive. **BLOCKED** means a concrete prerequisite prevented the check. A screenshot of one state cannot prove a transition, process termination or successful reinstall; record before/after observations and the operator action.

Keep raw physical logs/result bundles and original images in a private local evidence location outside the source tree. Review and sanitize before copying a summary or cropped screenshot to public GitHub: omit hardware IDs, device owner names, Apple IDs, provisioning contents, certificates, tokens, personal notifications and unrelated screen content. Public CI logs use fresh hosted simulator identities; do not upload local physical evidence as CI artifacts.

## Finish conditions and next action

Foundation physical smoke evidence is complete only when both physical installs and launches, companion pairing, five phone labels, Watch Left/Right reset behavior, fresh-process arm retention/confirmation reset and readable reachable controls are observed against the exact source, with failures/gaps retained. Reconcile CI, independent review, evidence and Gate Card afterward. A merge still requires the owner's explicit approval.

This cannot establish Core Motion fidelity, recording continuity, WatchConnectivity delivery, data durability/export, Health/Motion permissions, battery effects, background capture, hit detection or contact-quality prediction: none is implemented here. Do not request swings, a court visit, Health/Motion access or practice labels for this run.

**Next action at preparation:** finish exact-HEAD CI and its independent review. No human device action is needed while those gates remain open. Once they pass, the first owner action is P01: verify the intended Watch in the iPhone's Watch app, with one instruction and one observation before proceeding.
