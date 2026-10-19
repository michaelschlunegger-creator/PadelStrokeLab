# Phone logger test contract

18 October 2026. Astra High bounded implementation following the approved physical-shot logger plan. Authority: PSL-SPEC-001 v1.1 S1-05–08/S1-10 and owner authorization for the complete tester. Branch `feature/watch-recording-storage`, base/HEAD `ee15c0ef86c99064bb1295c7550fba1daea66a3c`. Existing storage implementation is preserved. Xcode 27.0 (27A266a), iOS/watchOS27 SDKs verified before edits.

## Package P1 — review and owner labels (defined before production edits)

Allowed: new phone `RecordingLibraryModel.swift`, `RecordingLibraryView.swift`, `RecordingDetailView.swift`, phone unit/UI tests. At most three production files/2,000 lines; two Level3 domains: evidence review and annotation persistence. Shared schema/store/path/archive/transport ownership remains separate. No capture, shared-schema, project-configuration or Git mutation.

Production-path tests use isolated canonical directories, real `RecordingStore` and annotation persistence, and synthetic raw chunks only in test fixtures. Cover empty library, final/interrupted/corrupt status, retained counts, per-continuous-segment timestamp rate and maximum interval, pauses excluded from intervals, missing timeline explicitly unknown, append-only label revision, stable attempt identity/ordinal, unmatched category preserved, valid clock-anchored interval, rejected invalid/out-of-bounds/pause-spanning intervals, and note limits. Real files must prove raw bytes unchanged after label edit. Full history must survive reload.

Heavy inspection/statistics execute on a repository actor. One bounded chunk is decoded at a time, no whole-recording samples retained. Cancellation checks occur between chunks/records; model generation guards prevent stale navigation results. An unverified/corrupt recording never becomes a healthy result. Missing receipt and terminal-tail certainty remain explicit. No automatic quality score or ordinal-derived timestamp.

## Package P2 — explicit export, local deletion and home integration (defined before production edits)

Allowed: extend the same three phone files and update `ContentView.swift`/`PadelStrokeLabApp.swift`; at most five production files/1,000 added lines. Two Level3 domains: explicit evidence export and local data lifecycle. Consume existing shared archive/connectivity paths rather than inventing a transport. Activate WCSession on launch; callbacks refresh state on the main actor. Explicit share presents a streamed archive containing all label revisions. Export never runs automatically or uploads publicly.

Tests: export/import round trip preserves raw samples/metadata and full label history; export failure leaves a visible error; deletion requires a matching pending confirmation, cancelling leaves files intact, confirmed action affects only this phone's raw/notes copy; original Watch and independently shared files remain beyond this operation. UI tests preserve existing guide/back/accessibility identifiers, assert updated recording guidance, and exercise Sessions empty state/back navigation. Explicit delete confirmation must name copy/export scope.

## Verification and limits

Parent runs integrated app/core tests and both Release builds on OS27, retaining failed commands and exact source evidence. No retries conceal failures. Build success does not establish actual Watch receipt, physical motion, timing fidelity, background delivery, installation or playing-arm ergonomics. Physical paired-device receipt, labels, export and local deletion remain separate acceptance checks. No commit/push/merge/install is performed by this package.
