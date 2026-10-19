# Watch recording architecture review

17 October 2026. Reviewer: separate Astra agent, Extra High reasoning. **Review only; no file changes, production implementation or test execution.** This is a planning review, not an exact-commit final code verdict or merge authorization.

Baseline examined: `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, `chore/project-governance`; approved specification/governance/current foundation; installed Xcode 27 SDK headers and Apple documentation. Owner request: implement Watch motion recording after the simulator UI walkthrough.

## Recommendation

Implement a synchronous recording-model/codec/store package first. Count timestamp/evidence integrity and durable persistence/recovery as two Level 3 domains. Full recording adds independent sensor, session authority, concurrency, workout/background and permissions risks; it cannot honestly fit the same two-domain package. Separate later packages require bounded contracts before production work.

Keep existing practice metadata/codec unchanged. Add only `RecordingModels.swift`, `RecordingChunkCodec.swift`, `RecordingStore.swift` in the core package, their tests and supporting documentation. No UI, sensor, workout, permission, entitlement, project configuration, async controller or transport changes in the first package.

Preserve per-stream source timestamps/identity, separate clock domain and wall-clock anchor, exact counts/units/channels, deterministic bounded bytes and checksums. Proposed chunk limit is 1 MiB. Synchronize and atomically publish immutable chunks before updating the manifest. Require clean finalization for completed status. Interrupted/corrupt evidence remains visible and originals are preserved. Do not promise zero loss, a duration or battery performance before measurement.

Tests must cover real temporary filesystem storage, fault injection at all commit boundaries, abrupt child-process termination, corrupt/truncated/missing/orphaned files, invalid schemas/values/timestamps/counts, size limits, deterministic encoding and safe repeated inspection/finalization. Existing regressions/builds and later CI/review/physical gates remain required.

For later live capture: use a runtime-supported batched Core Motion stream during an active HealthKit workout, without silent fallback. Proposed activity `.other`; `.paddleSports` is inappropriate for padel. Minimize authorization; omitting a saved workout summary does not establish that watchOS writes no Health/activity metrics. Test actual behavior. No public final-tail flush guarantee exists: retain last observed samples and stop/pause boundaries without inventing complete coverage. Bounded ingestion, late-callback fencing, resource cleanup and interrupted recovery are mandatory in later contracts.

## Decisions required

Owner approval of the proposed plan/data-storage contract and a dependent-branch exception from `ee15c0e`, because main lacks the unmerged app foundation. Do not merge foundation prematurely or reuse historical evidence for changed code. Architecture approval does not itself authorize physical installation, publication, merge or release.

The plan/test contract incorporate these recommendations. Approval is **PENDING**; no recording code has been written.
