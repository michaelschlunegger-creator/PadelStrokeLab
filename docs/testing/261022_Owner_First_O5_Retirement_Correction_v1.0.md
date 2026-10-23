# O5 retirement correction — local verification

22 October 2026. Astra Extra High authored the foundational correction; root performed routine verification and Sol independently reviewed, without modifying files. Branch `feature/guided-padel-setup`, HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; this is unpublished working-tree evidence, not committed-HEAD CI or physical evidence.

## Source and correction

Frozen O5R-10 contains 91 source inputs. Manifest SHA-256: `c9934d8dbd54eb9bf7630d526a76cbb46acc9ed0f918f4d61b3a743fbdee7e4f`; archive SHA-256: `8d5d593fbc4381d00f2b9aef3a9e528dad3fa9dad8b72413fdf90308d930b5e8`. Root and reviewer independently confirmed all current input bytes match.

Only `OwnerCaptureCoordinator.swift` changes against source42: +5/-1, six changed lines within the 120-line correction cap. Seven-file O5 production scope totals 1,801/2,400 added-plus-removed lines. Tests-first correction is 254/300 changed lines in `OwnerCaptureAdmissionTests.swift`.

The coordinator validates original correlation, fences ingress synchronously, rotates preparation generation while preserving runtime, uses the real checked authority advance for Cancel and practice retirement for End, and rechecks work cancellation after suspension. Actual writer/native closure gates remain intact. No Core, wire, consent or O7 ownership change belongs to this correction.

## Evidence

Private evidence root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/PhysicalReadiness1/`. Every named run retains its full command, log and result. Xcode 27.0 (27A266a), iOS/watchOS27 SDKs; commands explicitly set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

| Run | Result |
| --- | --- |
| O5R-08 focused red | Exit65, 8.992s. Ten success-path parameters fail actual retirement codec correlation; four store-fault parameters pass. No skips/crashes/harness failure. Post-test diagnostic collection error72 retained separately. |
| O5R-14 focused green | Exit0, 12.908s. All four exact methods/14 parameters pass. |
| O5R-18 full Watch host | Exit0, 11.139s. Exact 48 enabled method IDs match R06 enumeration; 67 parameter-expanded executions, no failures/skips/runtime warnings. |
| O5R-22 Watch UI | Exit0, 95.583s. Exact six selected methods match R06, all pass with no failures/skips/runtime warnings. |
| O5R-23 phone Release | Exit0, 22.519s, unsigned generic iOS Simulator Release build. |
| O5R-24 Watch Release | Exit0, 22.519s, unsigned generic watchOS Simulator Release build. |
| O5R-19/21/25 guards | Pass; final guard 0.645s. No additional default-container changes since retained incident46 only. |

Fresh runner O5R-20 SHA-256 `2f43d05cba0e662830e0c70886aa361e086ee25bb80f05bb340a9c02a0df5980` isolates both eager app hosts and validates 79 expanded product paths. Host and UI commands preserve all original exclusions. `git diff --check` passes.

Independent reviewer exclusively extracted R18 and R22 xcresults and checked exact IDs, expanded cases, failures/skips/warnings and logs. Earlier O546 screenshots support the unchanged UI's simulator-block/fresh-check/relaunch behavior; they are prior-source images, not current R22 visual captures.

## Verdict and limits

Independent verdict: **SAFE WITH NON-BLOCKING NOTES — local O5R correction only.** Root accepts this bounded checkpoint and re-releases the previously approved three-file O6 implementation. The prior retirement blocker is resolved for these exact local bytes.

Physical testing remains **NOT READY**. O6–O11, current pushed CI, formal committed-HEAD review and physical-device evidence remain open. The retained default-container incident46 is not erased: guards establish no further mutation, not original defaults unchanged. Three declared default-path/launch-performance exclusions remain open. Builds are unsigned simulator products; no new physical installation, publication or merge has occurred.
