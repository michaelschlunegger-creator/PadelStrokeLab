# Owner first build O1 — independent local source review v1.0

21 October 2026. Independent Codex review, Astra Extra High role. Review only; the reviewer changed no production, test or configuration files and ran no builds/tests or device operations.

**Local package verdict: CLEARED FOR THE NEXT BOUNDED PACKAGE. No unresolved O1 blockers.** The director may hand off O2 from this exact source. This working-tree review is not formal committed-HEAD G6, a merge verdict, or completion of the owner-first build.

## Exact scope and evidence

Reviewed the two new production files, `OwnerPracticeIdentity.swift` and `OwnerRecordingContext.swift`, their two new core test files, reused raw/setup validation boundaries, and the [O1 evidence record](../testing/261021_Owner_First_O1_Local_Evidence_v1.0.md). Scope is **447 production lines**: 291 identity/policy lines and 156 context/binding lines, within the approved two-file/1,200-line limit. No existing production/configuration/test input changed.

- Branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; intentional unpublished changes and no upstream.
- Reviewed [source manifest](../testing/261021_Owner_First_O1_Source_v1.0.sha256), SHA-256 **`011867981ae4313fad0a94d11395611b4a49738ea261d1df453c9460de9d8549`**. Independently verified all **73 entries after the final builds**; all 69 preceding baseline entries remain unchanged.
- Evidence document SHA-256 **`b7b733ebda8d8c794207d7c1a13ca75f6795aa6f7576ca057b3a4cbd3d117d21`**.
- Private `O1/evidence.sha256` is **`b78360b368334219f0b63e046f30454394a141c526a5af5ac8aa972516fb76b5`**. Independently verified all 19 included logs/vectors.

| Final evidence inspected | Result |
| --- | --- |
| `11-frozen-core.log` | 157 tests in 15 suites passed, including the new owner identity/context tests and corrected clock/capacity regressions. |
| `12-frozen-phone-release.log` | `PadelStrokeLab` Release build succeeded with OS27 simulator targets. |
| `13-frozen-watch-release.log` | `PadelStrokeLab Watch App` Release build succeeded with OS27 simulator targets. |

Both final Release logs show `arm64` and `x86_64` simulator compilation. They do not establish `arm64_32` execution, signed-device compatibility, UI behavior or physical sensors. Revision arithmetic remains `Int64`; the inspected conversion of consent generation to `Int` follows validation that it is at most128. This static check is not a substitute for later relevant device-build evidence.

Independently recomputed canonical JSON and SHA-256 checks for the final policy, identity and context vectors, plus the raw metadata vector. They match the literal expectations used by the production-path tests. Final policy digest is `7bb8c65e14078fa2cb1621449005448abd1e450848eadedaf3a6647e897769dd`.

## Findings resolved before this freeze

| Finding | Verified correction |
| --- | --- |
| A backward wall-clock correction could prevent HR-disable or withdrawal. | Authority order now depends on exact revision/generation/barrier, while finite nonnegative reported timestamps are retained without requiring chronological increase. The dedicated failing clock regression is preserved, and the corrected final test passes. |
| Reserving only one decision/revision slot could leave no room for optional HR-disable followed by full withdrawal. | An active HR grant reserves two reductions; an active motion-only grant reserves one. At the boundary HR can be disabled and then full consent withdrawn. The failing capacity regression remains preserved, with the final chain verified. |
| Context decoding admitted terminal authority ranges which could not describe a valid active identity. | Context validation now uses the same HR-dependent revision/decision reserves. Recomputed-checksum endpoint fixtures reject impossible active contexts. |
| The concrete consent text omitted the already-approved retention rule. | The digested text now explicitly states local retention until deletion, refusal of new content instead of silent eviction, and no app-saved workout summary. Independent vectors were regenerated and final tests/builds followed the change. |

The initial missing-type test failure and both genuine regression failures are retained. Intermediate green runs are not substituted for the final source evidence.

## Source conclusions and handoff obligations

The public authority values require explicit exact owner/phone/Watch attestation, policy binding and revision-bound decisions. They provide no alias, guest, slot, import-restoration or owner-role-transfer path. Withdrawal/re-consent barriers and retained decision IDs prevent normal API replay from renewing an obsolete grant. A checksum is corruption detection, not authentication or proof that a human declaration is true.

The context factory requires exact canonical raw metadata and compatible forehand/backhand setup, arm/wrist/crown, protocol, supported streams and phone origin. It freezes the owner, consent and practice identities plus both setup generations. The checked binding retains exact authority/raw bytes; a current authority change invalidates it. Historical decode returns only a context, never a publication binding or Start token. Unknown fields, duplicate/noncanonical payloads and malformed bindings are rejected through the real codecs.

O1 deliberately contains no filesystem or runtime adoption. It cannot prove that a recording ID is new, prevent a caller from presenting pre-existing compatible metadata, persist replay guards, confirm actual wearer, or stop resources. O2 must durably reject existing/failed IDs and namespace reset, and O5 must enforce current setup/physical authority and the approved Start/shutdown ordering. No legacy recording gains an owner assignment merely because these types now exist. These are retained package obligations, not new scope or proof supplied by O1.

Keep the O1 production/tests and manifest frozen during O2. Any correction to them requires an explicitly identified source change, affected verification and renewed review before dependent work. Formal committed-source review, exact pushed CI, physical G7 and user-authorized publication/merge remain open.

**Next action:** director accepts this exact O1 freeze and releases the independently bounded O2 persistence package.
