# Deterministic lease correction review — v1.0

19 October2026. Astra Extra High; review only, no file changes/tests/builds. Reviewed frozen working-tree correction against committed8075991 under the [pre-edit contract](../testing/261019_Deterministic_Production_Lease_Test_Contract_v1.0.md).

Result: no code defects or contract blockers found; proceed with planned verification. This is not the final committed-HEAD review or a merge-readiness verdict.

- Engine SHA256 `95334d37e5622e352617d0b676efab1aab86444317bd5de119a0a293f1562585` matches. Public uptime default and exact real lease/writer/store/timeline wiring are preserved. Timer, watchdog, serial queue and failure handling are unchanged.
- Engine tests SHA256 `a5f7a58337e60c99e2a8bcb28200a0533ac79e957e448693667960a049f2399a` matches. The success regression establishes both-stream Recording, lease exclusion during Starting/Recording/Paused, then Saved/release, both original samples, finalization and persisted timeline.
- Missing-stream regression proves exclusion before five seconds, exact device-motion interruption at five seconds, retained durable data and lease release. Later Stop preserves interruption, finalization and bytes.
- Ordered checkWatchdog/snapshot barriers observe queued finalization correctly. The real timer and manual checks serialize on the worker with guarded terminal requests. Fixed clock values remove host elapsed-time dependence; explicit fixture lifetime protects files through asynchronous observations.
- Reviewed15-minute CI core step is present. Preserve baseline CI failure and parent command14's invalid xcrun invocation; neither is a passing run.

Focused/full local results, affected builds/signing, exact-HEAD CI, separate committed-source review and physical evidence remain distinct gates. See [current evidence](../testing/261019_Complete_Training_Local_Evidence_v1.0.md).
