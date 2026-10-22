# Existing-motion statistics — package A contract v1.0

20 October 2026. Read-only design by Astra Extra High; consolidated before source edits. Owner requests useful wrist statistics before shot collection. Authority: latest [product amendments](../PRODUCT_AUTHORITY.md), [expanded proposal](../architecture/261020_Reference_Training_and_Statistics_Plan_v1.0.md), governance and active gates. This contract does not authorize new sensors, Health/GPS permissions, participant reassignment or physical collection.

## Bounded source and integration

At most four production files, 1,200 changed production lines, one Level3 domain: faithful interpretation of retained evidence:

1. New `Packages/PadelCore/Sources/PadelCore/MotionStatistics.swift`.
2. Existing `PadelStrokeLab/RecordingLibraryModel.swift`.
3. Existing `PadelStrokeLab/RecordingDetailView.swift`.
4. New `PadelStrokeLab/RecordingStatisticsView.swift`.

Focused new/extended core/app/UI tests and package evidence/manifests support only this scope. Do not edit capture, raw schema/codec/store, Watch runtime, setup/participant contracts, archive/transport/export/delete semantics, signing, entitlements, permissions, dependencies or project settings. Native Swift Charts exists in iOS27 SDK; synchronized source groups permit the new view without a project-file edit. Keep existing unrelated working-tree changes intact.

Frozen preceding checkpoint is phone-setup P1 manifest SHA-256 `ca4332e66eaf46077a99df949d1d9d0d20895917c02af21db0fce24b64b15171`, HEAD `bc5e73d`, branch `feature/guided-padel-setup`. Separate P1 review found no source blocker; all64 entries match. Package A changes two of those existing entries deliberately and adds two production files; do not overwrite that immutable manifest or transfer unchanged-source evidence to the changed files. Verify Xcode27/both27SDKs before edits and use explicit DEVELOPER_DIR for every Swift/Xcode command. Evidence/build outputs stay outside source.

Use the existing `RecordingLibraryRepository` actor detail-review pass. It already inspects files, validates SHA/bytes and decodes a bounded chunk at a time. Feed decoded chunks into a new pure reducer before releasing each chunk; no second reading pass, full sample-array retention, work on MainActor or expensive library-list analysis. `includeStatistics: false` remains lightweight. Present completed compact Sendable results; keep stale-selection generation checks and propagate cancellation to repository/reducer.

## Quantities and honest interpretation

| Metric | Exact retained source | Units |
| --- | --- | --- |
| Gravity-removed wrist acceleration magnitude | Device-motion components6–8 | g |
| Wrist angular-rate magnitude | Device-motion components0–2 | rad/s in core; °/s in presentation |
| Raw acceleration magnitude, including gravity | Accelerometer components0–2 | g; expandable detail |

Per metric return peak, **RMS of eligible retained samples**, eligible count and bounded chart points with actual timestamps and active-segment identity. RMS is `sqrt(sum(magnitude²)/count)`, not arithmetic/time-weighted mean, energy, effort or intensity. Use stable magnitude/scaled-sum arithmetic. Nonrepresentable derived results become explicitly unavailable, never clipped/plausible zeros. No-sample/missing-stream state remains optional/unavailable.

Only samples inside validated known active segments qualify. Validate finite ordered segment bounds, recording/clock identity, declared stream/component shape and per-stream sample order; streams need not be synchronized. Boundary samples count once according to existing review semantics. Preserve elapsed time relative to original recording anchor; never collapse pauses. Reject excessive segments rather than truncate.

Missing/unusable timeline/metadata or corrupt/inspection-limited input withholds the new dashboard while retaining existing raw review. Integrity errors and cancellation must not be swallowed into a successful partial dashboard. Interrupted recordings with valid retained input may show **Retained portion — interrupted**. Retain existing stop-tail, interruption and rate/gap notices; do not add percentage-complete claims.

No stroke count, contact score, detected variety, wrist linear speed, body travel, HR, calories, participant comparison or cross-recording aggregation belongs here. Selected intended drill is not a detected class. This single-recording dashboard does not attribute unassigned historical records to the current player.

## Bounded charts and cancellation

Maximum256 time buckets per metric across all active segments. Allocate one per segment, then remaining proportionally by duration with stable tie-breaking; zero-duration segments use one. Each bucket retains actual first/minimum/maximum/last samples, earliest-timestamp extrema ties, deduplicated and sorted by time. Maximum1,024 points per metric/3,072 total. Never synthesize uniform samples or bucket-center timestamps. Output consists only of compact summaries/points, not raw arrays.

Use point traces, without connecting/smoothing/interpolating missing intervals. Color is not the sole series identifier. Keep opaque theme cards, units/numerical textual equivalents, VoiceOver summaries, largest-text wrapping/vertical layouts, light/dark/landscape and Reduce Motion. No demonstration data appears as actual measurement. Raw acceleration remains an expandable secondary view.

Check cancellation before each chunk read, at least every256 reduction samples, and before publishing the completed result. Tests inject deterministic cancellation without sleeps. Preserve current bounded synchronous inspect behavior; no false guarantee about cancellation latency inside unchanged store inspection.

## Tests defined before implementation

Core production reducer tests:

1. Raw vector3/4/0 →5g, user acceleration0/0/0.5 →0.5g; rotation0/0/π →πrad/s and display180°/s.
2. Sample magnitudes3/4 →RMS sqrt12.5, distinct from mean3.5.
3. Different chunk boundaries produce identical summaries/points for identical ordered samples.
4. Missing stream/no samples/single sample optionality; independent unsynchronized stream times.
5. Paused/outside-segment exclusion, exact boundaries counted once, original elapsed time preserved.
6. Gaps remain gaps; no synthetic points/lines.
7. Peaks at bucket/chunk boundaries survive and extrema ties are deterministic.
8. Large input stays within fixed point/memory budget; excessive segment count rejected.
9. Large finite vectors use stable arithmetic; nonrepresentable results explicitly unavailable.
10. Wrong recording/clock/shape/order and invalid bounds rejected.
11. Deterministic cancellation returns no completed dashboard.

Real app-host fixtures through RecordingStore/codec/timeline/repository:

1. Two-stream paused recording returns expected summaries/points while old coverage values remain unchanged.
2. Raw/metadata/timeline/label bytes before/after repeated review remain exactly equal; original export bytes/semantics unaffected.
3. Interrupted and corrupt input retains truthful availability/status.
4. Cancellation and changed recording selection cannot publish stale results.

UI: populated/unavailable/interrupted synthetic fixtures; numerical/units/VoiceOver assertions; portrait/landscape/largest Dynamic Type; actual light/dark screenshots. Explicitly label fixtures **SYNTHETIC UI REVIEW**. Never treat this as hardware, court or paired-transfer evidence. Preserve every failing command/test and fix causes without weakening assertions or automatic retries.

## Gate and exit evidence

Independent architecture/contract challenge and director ratification precede source changes. Define tests first, preserve expected initial red, then bounded source. Run full core regression, affected phone app/UI suites, both OS27 Release builds; keep failures, exact commands/results, source inventory and actual visual inspection. Freeze final source and obtain separate read-only review. Formal committed-HEAD review/CI and relevant physical evidence remain separate gates before merge/readiness. No Git publication or physical installation is authorized by this contract.
