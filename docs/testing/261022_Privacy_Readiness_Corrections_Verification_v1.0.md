# Privacy readiness corrections — verification

22 October 2026. Branch `feature/guided-padel-setup`; correction base `7d5dc2a54f2157631254272131fbace60f6533f1`. This supplements the [original local results](261022_Owner_First_Final_Local_Verification_v1.0.md), the [committed review](../reviews/261022_Owner_First_Committed_Review_7d5dc2a_v1.0.md), and the [bounded contract](261022_Privacy_Readiness_Corrections_Contract_v1.0.md). The original candidate is blocked; those passing tests do not clear the three subsequently identified defects.

## Environment and preserved failures

Xcode 27.0 (27A266a), explicitly selected through `DEVELOPER_DIR`. Only the designated disposable simulators are used. Private result bundles/logs remain in `~/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/PhysicalReadiness1`; no device identifiers, real readings or personal recordings belong in this public repository.

- `Privacy-P1-01-red.xcresult`: failed to compile a newly added Swift Testing expression. The throwing timeline read was then hoisted before `#require`; no assertion was changed. This is a harness failure, not a runtime reproduction.
- `Privacy-P1-02-red.xcresult`: runtime failure, 9 methods, 4 passing and 5 failing, zero skips. The new actual-recorder deletion tests reproduce retained owner context, destructive legacy fallback when owner evidence is damaged, and an unpublished bundle surviving complete-practice deletion. The legacy copy-only control passes. Two pre-existing methods also fail because the direct launch omitted the UUID-isolated host argument; this failure is preserved and subsequent runs must use the established isolated `xctestrun` pipeline. Production remained unchanged for this red.

## Watch correction

The three Watch production paths now use the existing attributable readback namespace before import/publication, route verified owner records through complete-practice deletion, preserve context-free legacy deletion and fail closed for damaged owner evidence. Retained discovery remains available after withdrawal. Core production/tests are unchanged. Independent source review cleared this bounded correction.

`Privacy-P1-03-build` and `04-build` pass. The pre-import rejection fixture was corrected to create its intended receipt namespace before adding invalid content; its intended failure boundary is explicitly required. Focused05 passes 11 of 12 methods; the new relaunch check exceeds a generic two-second UI-state polling budget. Diagnostic07/09 preserve that failure and locate it before the deletion worker, during owner-evidence verification. Failure-preserving diagnostic11 passes without entering its diagnostic tail; this exposes timing intermittency and does not erase the previous failures.

Independent review approved returning the recorder action's existing Task so owner-path tests await the actual operation under the unchanged Xcode test timeout, retaining every durable cleanup/status assertion. Legacy callback completion retains its prior observation. There is no ownership-check or product-control-flow relaxation. Final build12 passes; focused13 passes all 12 methods, zero failures/skips. Full Watch14 passes all 130 methods, zero failures/skips (344.627 seconds of test execution).

Exact P1 source archive `Privacy-P1-12-source` contains 115 inputs; manifest SHA256 `6ee26ff48502287670a8a40de264cd8f20948d487f2fc904af425304e51e653a`. Subsequent phone-only changes do not change Watch/Core inputs.

## Phone correction and remaining gates

P2 red02 reproduces the three analysis defects: 11 methods, 8 passing and 3 failing, zero skips. The initial three-path correction builds successfully. Full phone host04 passes 71 of 73 methods; two existing legacy concurrent-review tests expose overbroad loading/generation invalidation during initial setup publication. Their original assertions remain unchanged. The narrow correction restricts that invalidation to an existing owner detail, retaining synchronous export clearing, admission fencing and final sanitization. A new test covers metadata-only owner deletion after a withdrawn relaunch. Independent source review clears the amendment; affected runtime/UI/Release/signature verification is pending.

Final corrected build05 passes; full phone app-host06 passes all **74 methods**, zero failures/skips. Targeted UI07 passes all **4 methods**, zero failures/skips: both intended strokes/export preview, excluded/absent/legacy heart-rate behavior, whole-practice deletion/peer-pending presentation, and largest-text portrait review with all five original native accessibility audit categories. Unchanged landscape and other complete phone UI checks remain in exact-head CI; the original 39-minute suite is not redundantly repeated locally.

## Final source and build identity

`Privacy-Final-Source1` freezes all 115 portable inputs. Current manifest SHA256: `1850b6e4802b6fb8218cd9812ee3037bd159071e042e832ce946ad9523a25f67`; all 115 worktree hashes match. Watch/Core inputs are identical to the full Watch14 run. Core production/tests remain identical to the previously passing 388-method/696-execution run; CI explicitly runs the full Core suite with `--no-parallel`.

Both current Release builds pass (`Privacy-Final-04-phone-release`, `05-watch-release`); schemes/destinations are PadelStrokeLab/iOS27 Simulator and PadelStrokeLab Watch App/watchOS27 Simulator on the designated disposable pair. Signed generic-iOS Debug build02 passes and embeds the separately signed Watch app. `Privacy-Final-03-signature-validation.json` verifies deep/strict signatures, current provisioning, signed identity/profile-pattern compatibility, actual connected-device coverage and companion identity. Both display **Padel Master**, version1.0/build6. Phone executable SHA256 `ec3f132ca4097ba2f40b9a76115eab15989180b9a497d5fd21341e08eed2d0df`; Watch `7f5bb7091c92825815f2050230dabdd8e060b988ea992aa6bd276af99aa2c575`.

The earlier signed build01 remains historical evidence. The final correction diff passes whitespace checks; the original committed candidate's separately disclosed blank-EOF observations remain historical. Independent source review clears P1, P2 and the two narrow synchronization amendments; exact committed-head review/CI remain pending at publication.

Both physical devices are separately observed connected, booted, with development services and developer mode available. No installation, recording pass, merge or release is established by this document. Live exact-commit CI, independent review and separate installation observations are recorded in PR#3 and linked evidence without changing the tested source merely to record subsequent outcomes. Physical sensors, background continuity, permission behavior, transfer reliability and battery remain UNKNOWN until the controlled dry run.
