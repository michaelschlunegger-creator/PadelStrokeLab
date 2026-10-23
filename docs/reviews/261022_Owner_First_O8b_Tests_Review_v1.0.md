# O8b transfer tests — independent local review

22 October 2026. Separate non-Astra Sol read-only verdict: **ACCEPTED bounded O8b tests and final evidence.** Not formal G6, merge clearance or physical readiness.

Tests01 froze 105 inputs with all 102 O8a predecessor inputs unchanged and zero production delta. Manifest `765ddcdb020a40dcd9d3566ec69960537dabca4789b31a64176f746631f91f5d`; archive `d93392d787121428d8ff1ac30bf7b6a877211091661206a8beba7d426a68046b`. Three new Core/phone/Watch `OwnerPracticeTransferTests.swift` files define 18 methods/26 expanded executions. Missing-interface reds02/03 were retained before implementation.

Coverage exercises durable offline queue/restart, complete receipts versus raw receipts, lost acknowledgement, conflicts/revisions, retry/source retention, ephemeral connectivity URLs, phone complete-library receive/select/export/readback and consent/publication races through actual retained workers. Watch fixtures join actual O6 raw evidence and existing sole connectivity. No invented shutdown or competing authority store.

Initial Core05 failed before transport at the strict symlinked temporary-root boundary. Read-only diagnostic07 established C realpath's canonical /private/var root. Astra High changed only the Core trusted-root helper to the established O6 pattern and hoisted three throwing Watch expressions outside macros. Separate review accepted those narrow corrections without assertion or production weakening. Corrected tests08 have unchanged 18/26 scope; all production remains exact.

Final test hashes:
- Core: `f6a3a0a71ef802916acafa80d8d602720eb8fd253d0fdbdf0bbf5fcf76da4cd7` (287 lines, 6 methods/10 executions).
- Phone: `4c2b0777b33e1aa28e1913a7d750ae0f4027cb5b4949355f1d87ecbac25fdbb4` (379 lines, 7/8).
- Watch: `93b72be960a3f9262ae592c8ae1345699164ed5856d5df4879ab25404a4e4f02` (321 lines, 5/8).

Final focused and regression execution passed on source20 with zero failures/skips; see [exact final verification](../testing/261022_Owner_First_O8b_Local_Verification_v1.0.md). Original failed results remain preserved.
