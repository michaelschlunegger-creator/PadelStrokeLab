# Owner first build O3a — independent local source review v1.0

21 October 2026. Independent Codex review, Astra Extra High role, for authority ordering and wire integrity. Review only: no production/test/configuration changes, builds/tests, device actions or Git mutations. This authorized report is the only file written during the O3a review.

**Local package verdict: CLEARED FOR THE NEXT BOUNDED PACKAGE. No unresolved O3a blockers.** The director may release O3b from this exact source. This working-tree review is not formal committed-HEAD G6, a merge verdict, physical readiness or completion of the owner-first build.

## Amendment clearance

The reviewer independently cleared the [O3 sequencing amendment](../testing/261021_Owner_First_O3_Sequencing_Amendment_v1.0.md), exact SHA-256 **`b64a693e8ce56054cdb80890bb838fa06ba4970c6afd390e69277f7fade957eb`**, before the director ratified it and released O3a only. Its bytes remain unchanged.

Early review identified that independent phone/Watch authority writers could produce incompatible histories when offline Watch retirement raced a phone withdrawal. The ratified amendment makes Watch the sequencer and requires exact explicit transition mirroring. It separates pure values (O3a), durable journal and phone intent ownership (O3b), and completion-counted transport (O3c). O3b owns persistent intent creation/dispatch/resolution; sent restrictive requests cannot be cleared by a lost reply or local cancellation. The reviewed bounds, restrictive/End reserves, O2 interruption recovery and distinct caller/worker completion obligations are retained. No source acceptance for O3b/O3c is implied by this amendment clearance.

## Exact reviewed source and evidence

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; intentional unpublished work and no upstream. Branch/HEAD/upstream were rechecked at review closure. The complete new production file and tests were read, including the correction described below.

- [Final source manifest](../testing/261021_Owner_First_O3a_Source_v1.0.sha256): SHA-256 **`2eeb0d1107418a3eff3e95ee20150b46e42a9ed3cd1098e0cdeb4c078a95e96b`**. All **77 entries** independently match; all **75 accepted O2 entries remain unchanged**.
- Exactly two additions: `Packages/PadelCore/Sources/PadelCore/OwnerPreparationMessages.swift`, **591 production lines**, SHA-256 `f54ee7a2bd8ec82ce6c936a55bd7b283313fcf76cb3b0271a2a8c24a71c586e3`; and matching `OwnerPreparationMessagesTests.swift`, **297 test lines**, SHA-256 `b451835344a3ab0832d2e890d4585aa069a89df0b77e9c47e825371716cba22d`. Within the one-production-file/750-line cap and two approved domains.
- [Evidence record](../testing/261021_Owner_First_O3a_Local_Evidence_v1.0.md): SHA-256 `1a08a22446ec278b8b1983cbd7bf999ba0709d0df0f9ab8390d56c3b00156190`.
- Private evidence: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O3/`. Its `evidence.sha256` is `8dc54af10b309e959af43adb935f68277cd7af09fa250e477b95ab37a334f7b7`; all **nine entries** independently match. The private `06-source.sha256` equals the public manifest byte for byte.
- Private `Checkpoints/03a-o3a-source.tar`: SHA-256 `a4c78765733f22d1431e911e43cecdb8d11a2304931a3d991b0815f75935e70c`. The checkpoint digest and all **77 source payloads inside it** independently match the manifest, without extracting or changing workspace files.

| Final evidence inspected | Result |
| --- | --- |
| `07-frozen-core.log` | **192 tests in 17 suites passed**, including all 13 O3a tests. |
| `08-frozen-phone-release.log` | `PadelStrokeLab` Release build succeeded, generic iOS Simulator. |
| `09-frozen-watch-release.log` | `PadelStrokeLab Watch App` Release build succeeded, generic watchOS Simulator. |

Both Release logs compile the new source for OS27 `arm64`/`x86_64` simulator targets. Only the existing App Intents extraction warnings for targets without that dependency remain. These are host unit tests and simulator compilation, not radio/background execution, physical-device or `arm64_32` validation. The reviewer ran no tests/builds.

The initial missing-type/fixture-spelling failure (`01`), short-circuit throwing-expression compile failure (`02`) and genuine retirement correlation failure (`04`) remain preserved. The first 13-test pass (`03`) is superseded by the corrected focused run (`05`) and frozen full run (`07`). Duplicate recognition was correctly assigned to retained journal evidence: pure resolution accepts only the exact before-state, including repeated reconstruction from that same before-state, and rejects an already-after state.

## Finding resolved before freeze

Successful retirement replies initially omitted the retirement reason from correlation. A receipt for End practice therefore also matched Cancel preparation when the other correlation fields were identical. The reviewer reported this concrete gap; `04-retirement-reason-red.log` reproduces it with one failed test/issue.

The corrected receipt requires an explicit retirement reason and `isReply` compares it with the exact request reason. Acceptance receipts reject a retirement reason. Both cross-reason directions, absent reason, codec roundtrip, advanced authority and preparation-generation rotation are covered in the retained final tests. No unresolved finding remains.

## Source conclusions and handoff obligations

Compact commands bind exact owner/paired epochs, policy, operation identity, before revision/consent generation/barrier and before/after digests. They reconstruct through frozen O1 factories from the exact before-state; they do not import status into a store. Only initial revision1 enrollment carries a complete authority value. Restriction rebasing requires matching identity/consent/barrier and retains decision identity/time; O3b must first prove every intervening revision-only transition. Grant/re-consent cannot use that helper.

Transitions, ACKs and replay cursors validate their semantic fields. A transition sequence equals its resulting authority revision; an ACK binds the exact transition/result, and replay admits at most one contiguous successor. These values do not prove durable receipt. Preparations require an active owner, exact P1 identity, forehand/backhand and a supported playing arm. Acceptance binds the exact current/next identity and both generations. Retirement requires advanced authority, the same runtime generation, rotated preparation generation, cleared acceptance and the exact reason. Applied replies bind the full mutation; errors bind the full canonical request digest. Status remains observation only, with no remote Start operation.

Canonical decoding rejects unknown/duplicate/irrelevant fields, unsupported kinds/versions, noncanonical alternatives and oversize data. Commands/transitions are bounded at 4 KiB and wire messages at 32 KiB. The maximum O1 history fits tested status and narrowing/withdrawal messages. No filesystem, WatchConnectivity or app adoption is present; frozen O1/O2/P1 and existing raw receipt semantics are unchanged.

O3b must implement durable append-before-apply, exact chain-node recovery, pending phone intents, exact contiguous ACK/prune and the guard-present/authority-before retirement edge. Mutation classification alone is not reserve authorization: only actual HR true-to-false uses that reserve, generic advancement is not automatically End, and redundant controls cannot spend another reserved slot. Capacity/revision/durability failure must preserve shutdown and blocked admission. O3c must retain the shared admission lease until actual handler completion or confirmed cancellation. O5 still owns observed resource shutdown and fresh physical admission; no pure receipt proves either.

Keep O3a and every predecessor frozen during dependent work. Corrections require an identified amendment, affected verification and renewed review. Formal committed-source review, exact hosted CI, physical G7 and separately authorized Git publication/merge remain open.

**Next action:** director accepts this exact O3a freeze and separately releases O3b.
