# Logger publication preflight — v1.0

## Owner authorization

On19 October2026, the owner replied “approve” to the concrete proposal to commit/push `feature/watch-recording-storage`, create its draft PR into `chore/project-governance`, and run exact-HEAD CI and Astra review. This supersedes approval-pending next-action wording below. Publication verification will record actual commit/remote/PR identities; no merge or release is authorized.

19 October 2026, Asia/Dubai. This is a bounded CI identity/documentation increment before Git publication. No app, sensor, workout, transport, UI, entitlement, signing or test source change is authorized by this increment.

## Verified baseline

Branch `feature/watch-recording-storage`, HEAD/base `ee15c0ef86c99064bb1295c7550fba1daea66a3c`, no upstream. Remote foundation is unchanged; main `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`; foundation draft PR1 remains open/unmerged. Logger changes remain local. All52 files match [the final app/test manifest](261019_Physical_Logger_Top_Scan_Code_State.sha256), SHA256 `a70de47a76f8d9fc54eb08d22d634b0d5717effa0bc6ac00dd8a692570b0d988`. [Local evidence](261019_Physical_Logger_Local_Evidence_v1.0.md) records passing core/app/UI/build/signature results and preserved failures.

After the owner connected/unlocked the iPhone, fresh `devicectl device info details` calls succeeded for both physical devices: iPhone15Pro/iOS27.2 (24B5099f), WatchUltra2/watchOS27.0.1 (24R365). Both development tunnels are connected, Developer Mode enabled, DDI services available. The initial inventory's cached Watch27.0 value is superseded by the fresh details. The two signed build2 profiles include their respective observed hardware; deep/strict bundle signature verification passes. Exact device identifiers and raw logs remain private under the local DerivedData evidence root. Companion pairing between phone and Watch still requires verification; Mac-device pairing alone does not establish it. No physical installation or capture has occurred.

## Required process

Repository `AGENTS.md` requires Authority → risk/test contract → implementation → local automation → clean CI → independent committed-HEAD review → physical evidence. `ENGINEERING_GOVERNANCE.md` G5/G6 therefore remain prerequisites to G7. The latest Gate Card's earlier install-next wording did not waive those requirements. Do not install merely because devices are now connected. Commit, push and PR creation each require explicit owner approval; merge/release remain separate approvals.

## Bounded change and validation contract

Astra High implements two focused workflow-line changes only: replace the obsolete premium-UI source-manifest reference in `.github/workflows/foundation.yml` with `docs/testing/261019_Physical_Logger_Publication_Code_State.sha256`, and extend the existing pull-request base filter from `[main]` to `[main, chore/project-governance]` so the proposed stacked draft PR actually triggers checks. Parent generates that new52-file manifest after the workflow edits, preserving all historical manifests. Only workflow identity differs from the last passing source state; no app/runtime evidence is invalidated by this CI-only edit.

Keep runner, toolchain, actions, permissions, checkout semantics, test commands, destination selection and artifact policy unchanged. Validate the exact two-line diff, YAML structure/reference, the stacked base filter, all52 current file hashes and whitespace checks. No redundant app rebuild/test is required for these CI-only changes; hosted CI must still run on the approved published HEAD.

The filter amendment was defined before its implementation: direct GitHub lookup returned404 for the workflow on `main`. The existing `[main]` PR filter cannot run a PR based on `chore/project-governance`; relying on manual dispatch before the workflow reaches the default branch would not establish a usable publication path. Extend the filter narrowly to the existing foundation branch; do not change the PR base to mix the separate foundation review into this logger package.

Verified public runner documentation lists `xcode-27` with Xcode27.0/27A266a and both OS27 SDKs: https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md . No repository self-hosted runners are registered; that does not make the hosted label unavailable. Prior hosted job39031573652 actually used that runner and passed source/toolchain, pairing, core, both builds and phone tests, then failed Watch destination lookup (exit70). Run39031993296 on foundation HEAD was cancelled. Preserve those results; do not infer the new logger has clean hosted CI. No speculative destination fix is included; diagnose any current exact-HEAD failure from its evidence.

## Publication proposal

Once the local preflight is verified, request explicit approval to commit the scoped complete logger and supporting docs on `feature/watch-recording-storage`, push that new branch, and create a draft PR into `chore/project-governance`. This stacked base keeps the already-open foundation PR1 separate and does not merge either branch into main. The draft PR records risk, exact-source results, the untested physical boundary and open gates. CI and an independent committed-HEAD review follow before device installation. Merge and release are excluded.

Proposed PR title: **Add owner-led Watch motion recording and verified iPhone review**.

Proposed description: The owner needs to collect short, explicitly started forehand practice recordings before assessing whether Watch signals relate to perceived contact quality. This change adds Watch motion/workout controls, bounded durable recording and interruption recovery; verified file transfer; iPhone coverage review, revision-preserving owner labels, export and confirmed local deletion. The initial limit is120 active seconds and the final batched sensor tail remains unverified. It provides no automatic clean-hit score.

Validation:102 core tests; iPhone7 app-host+9 UI; Watch11 app-host+5 UI; both final Release simulator builds; signed physical build2 and signature/profile checks. Preserved failures and exact file identities are linked in the local evidence record. App/runtime files remain unchanged by the CI inventory/base-filter update. Physical installation/capture/transfer/background/battery observations, clean exact-HEAD hosted CI and formal committed-HEAD review are pending. This PR stacks on the unmerged foundation PR1; it must remain draft until the required gates pass. No merge or release is included.

## Local preflight result

Astra completed exactly the two approved workflow-line replacements; parent verified byte-for-byte equality with those replacements against HEAD. Final workflow SHA256 `da600146e23f929726c9601e6b0c6ca0e829f19eee03551a149ddaa335e3e28c`. [Publication manifest](261019_Physical_Logger_Publication_Code_State.sha256) contains52 verified files, SHA256 `52b5e092cb30eb8a7aac1a3a56d15c6a3119f55c6df80775d6f1047cf7383859`; only the workflow differs from the app/test baseline. Ruby/Psych parsed the YAML and verified both PR base filters and the manifest reference; Python PyYAML was unavailable, so it was not used. `git diff --check` passed. No app tests/builds were redundantly rerun for these workflow-only edits. No commit, push, PR creation, hosted run, installation or capture occurred. Next: request approval for the exact publication proposal above.
