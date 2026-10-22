# Owner first build O4a — independent phone bootstrap review v1.0

21 October 2026. Independent Codex review, assigned Astra Extra High role, for initialization durability, exclusive ownership and failure handling. Review only: no production/test/configuration edits, builds/tests, Git mutations or device actions. This authorized report is the only file written during the O4a review. The reviewer inspected source, preserved failures, execution logs, result bundles and fingerprints; the reviewer did not execute the builds or tests.

**Local package verdict: CLEARED FOR THE NEXT BOUNDED PACKAGE. No unresolved O4a source blocker.** The director may accept this exact bootstrap package. The initial app-host isolation failure is retained below; the separately ratified controlled run passes its protected-entry check. O4b remains held for its separate lifecycle design and release gate. This is not a committed-HEAD G6 review, merge approval, physical readiness or completion of the owner-first build.

## Exact package

Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; intentional unpublished work with no upstream. Branch and HEAD were independently rechecked after execution. Authority is the ratified O4 amendment SHA-256 `e58ca5466a7d95dc367415106f0f8a0310eac71643afd75d699456c407314867` and explicit release of O4a after exact O4p acceptance.

- [Source manifest](../testing/261021_Owner_First_O4a_Source_v1.0.sha256): **82 entries**, SHA-256 **`e1740faaa6a217d2f650d30635735db2db92f7792b6c316e6a495a5aea4f94fe`**. All current inputs match. All **80 accepted O4p inputs remain byte-identical**; only the two authorized files were added.
- `PadelStrokeLab/OwnerPhoneBootstrap.swift`: **181 production lines**, within the 250-line cap; SHA-256 `313dc2681ddd8b52b360166b2775cdb8c6340cc307cac6876cd7c1f6a0dc32df`.
- `PadelStrokeLabTests/OwnerPhoneBootstrapTests.swift`: **298 lines**, 16 test functions with parameterized cases; SHA-256 `cbedf5a705212b1303148ab2568033b648f64f60dfacb0dc35ae3984151e0c73`. No predecessor test or assertion changed.
- Checkpoint `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/Checkpoints/04a-o4a-source.tar`: SHA-256 **`3a9311116f18e4fd3defc5b2842f16cd7024df0bfbd90a0dc704d128fa09e25f`**. Independently verified all 82 payloads and the exact embedded manifest, with no other file payloads.
- [Local evidence](../testing/261021_Owner_First_O4a_Local_Evidence_v1.0.md): SHA-256 **`b9a92b40ae0f914766c8624802e70da6a2e8113f329dc9b7b0f49ca75e2f42dd`**.
- Private evidence root `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/O4a/`; `evidence.sha256`: **389 entries**, including retained result-bundle members, SHA-256 **`0d458206aca00d83f40708618e6ba3fd7e5261bd7e2261b9f6efd0c735ef9b8a`**. Every listed payload independently matches.
- Actual isolated runner and preserved `03-isolated-host.xctestrun`: SHA-256 **`93214c581d9044d22db0a0351d977112a650d0971c2bbd07c575191a8c097db1`**. Both copies match.

The accepted O4p source manifest remains `d2906f11be7e1c602bde308b80938c9b4e9fd6d28c2a963fd980a5c042c4aaf8`. Its **245 tests / 19 suites** full-core evidence carries forward only because every Core/package input remains exact. No fresh full-core execution is claimed for O4a.

## Source findings

The class explicitly declares `nonisolated` and remains non-Sendable. It is synchronous, privately retains exactly one P1 store and one O3b channel, and never separately opens O2. The channel retains O2 through the frozen API. The bootstrap retains its base and witness descriptors and exclusive nonblocking witness lock until deinitialization, releasing the stores before the witness lock.

Fresh initialization requires an absent witness and all three absent namespaces. The witness uses exclusive creation, no-follow and nonblocking access; regular-file, single-link and bounded-size checks precede use. Exact pending bytes are written and the file and parent directory synchronized before actual store construction. P1 is created through its real initializer and checked epoch; O3b is constructed as phone/createNew using that epoch. Ready is published only after actual store checks, using the same held witness inode through positional writes, truncation and file synchronization. No callback can merely claim that initialization happened.

Reopen requires ready bytes with the exact version, field count, trailing newline and canonical UUID spelling, plus all three directory namespaces. The loaded witness is synchronized; P1's checked epoch must match before phone/openExisting O3b construction. Pending, partial, missing, corrupt, foreign-role or foreign-epoch state is rejected. The bootstrap adds no reset, namespace recreation, independent recovery or cleanup policy; existing accepted store recovery remains delegated.

Live verification reopens the supplied canonical base through descriptor-relative no-follow traversal, compares it with the held base, checks named/held witness identity and exact bytes, compares all three captured namespace identities, and invokes both actual checked store APIs. `withStores` checks before executing the nonescaping body and again after either success or throw. Its saved `Result` preserves a healthy body's original error, while post-check failures take precedence and poison the bootstrap. A real conflicting restriction that saves an O3b fence and throws `intentOutstanding` therefore remains usable for explicit resolution; an integrity/ownership check failure remains sticky after fixture restoration.

The Sendable result bound and nonescaping body narrow the interface, but do not mechanically prevent a caller from retaining a store through a side capture. There is no production adopter in O4a. O4b must keep the bootstrap private on its non-main serial owner and must not retain either mutable store outside the closure. The canonical app-support base is outside `Recordings`, two parents above `RecordingPaths.rawRoot`.

## Test review and observed results

The original 285-line tests-first source and expected missing-bootstrap/type-dependent-stage compilation failure are preserved. Before the final freeze, review strengthened same-inode witness attacks and post-body tampering across P1, O2, the O3b journal and witness, and added an actual host-isolation assertion. The final source has 298 lines; it is not falsely represented as identical to the earlier red snapshot.

The tests exercise actual stores and isolated filesystem fixtures. Coverage includes fresh/reopen identity with no authority and preserved raw sentinel data; three faults after real pending/parent synchronization, P1 initialization and O3b initialization; seven invalid witness forms; missing/corrupt namespaces and total triplet loss; namespaces without witness; foreign channel role/epoch; lifetime contention; symlink/hardlink/directory/FIFO rejection; forbidden/symlink bases; base/witness/namespace replacement; four same-inode byte attacks before the body; and eight post-body attacks across successful and throwing bodies. Sticky poisoning is checked after restoring the fixtures. Healthy body errors and a real conflicting restriction/fence-resolution sequence are separately exercised.

| Retained execution evidence | Verified result |
| --- | --- |
| `01-tests-first-red.log/.xcresult` | Expected missing-bootstrap compilation failure; retained original tests-first source. |
| `02-build-for-testing.log/.xcresult` | Test build succeeded with final source/tests. |
| `04-frozen-app-host.log/.xcresult` | **Functional PASS: 30 tests / 4 suites, 1.700 seconds**; bootstrap suite 1.259 seconds. Its original default-container guard **FAILED**. |
| `05-frozen-phone-release.log` | Phone Release build succeeded, generic iOS Simulator. |
| `06-frozen-watch-release.log` | Watch Release build succeeded, generic watchOS Simulator. |
| `08-frozen-isolated-app-host.log/.xcresult` | **PASS: 29 tests / 4 suites, 1.545 seconds**, after the single director-approved exclusion; protected-entry comparison passes. |

Both Release logs use the installed Xcode application and OS 27 simulator SDKs with arm64/x86_64 targets. The evidence records approved Xcode 27.0 `(27A266a)` and explicit `DEVELOPER_DIR`. The two Release logs contain four existing App Intents metadata warnings in total and no error diagnostic; test build contains three existing metadata warnings. Runtime/enumeration framework and XPC diagnostics remain retained. No failed test or crash was discarded.

## Preserved isolation failure and controlled correction

The reviewer confirmed that the actual generated phone app-host runner supplies `--motion-statistics-fixture=unavailable`, selecting the existing temporary fixture and disabling connectivity in the app model. The new test verifies the actual process argument and synthetic mode. Runtime commands select only `PadelStrokeLabTests`, disable parallel testing and use reserved phone `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`; no UI test executed. The paired Watch `91757361-AEA2-41D8-9C4F-6DE5FF6365DA` is included in the default-data fingerprints.

The initial full app-host selection nevertheless included frozen `RecordingLibraryTests/defaultAppContainerCanWriteInspectAndAnnotate()`. Its source directly constructs default `RecordingPaths()`, creates a unique synthetic recording and removes that recording's raw/notes directories. Actual run04's result bundle confirms that test executed. Its original guard failed: the phone container path changed during the test period and the default raw/notes directory modification times changed. Entry sets and every captured retained-file entry were identical; all Watch entries and its container path were identical. The known direct-default test is consistent with the two directory-time changes. These end snapshots cannot establish that no transient writes occurred.

The director separately ratified excluding only that existing default-writing test, with unchanged source/assertions. The reviewer independently parsed the actual run04/run08 result bundles: **30 to 29 test functions**, exactly that identifier removed, no additions, all 29 remaining functions passed. All 16 bootstrap functions remained selected. Enumeration and the exact skip flag are preserved. This was a separately authorized selection correction, not a hidden automatic retry.

The original before/after/difference fingerprints and failed guard remain preserved; no timestamps were restored. The controlled run's `07-default-containers-before.json` and `07-default-containers-after.json` independently match for all protected entries on both devices: entry sets, captured mode/inode/mtime, and regular-file size/SHA-256. The phone container path moved again and is reported separately; the Watch path remained identical. The guard does not capture atime, ctime, extended attributes or all transient activity. Accordingly, this report claims the exact retained-entry comparison, not that all default metadata or transient activity was unchanged. The first guard is not relabeled as passing.

## Closure and remaining boundary

After execution, the reviewer reverified all 82 current and archived source inputs, embedded manifest, all 389 evidence entries and the sealed evidence document. Read-only `git diff --check` returned zero. No predecessor source/test/configuration file changed.

This package establishes the tested bootstrap and logical storage boundaries only. It provides no physical power-loss, paired delivery, sensor, background, battery, arm64_32 or user-facing app-adoption proof. Whole-container deletion/reinstall removes the witness and companion evidence; bootstrap cannot detect that history or restore prior consent.

O4b's independent practice identity, current-versus-next state, relaunch and End handling remain a separate gate. In particular, the frozen channel cannot durably add a second End request while another intent is outstanding: `request(retirePractice)` has no local restrictive fence and throws `intentOutstanding` in that case. A concrete approved persistence/API path is required before dependent O4b code. This is not an O4a defect and does not authorize an extra journal, identity alias, consent withdrawal substitution or UI-only workaround. Any prerequisite amendment and subsequent implementation still require separate director release.
