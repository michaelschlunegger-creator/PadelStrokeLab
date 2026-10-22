# Owner-first O4a — phone bootstrap evidence

21 October 2026. Implementation: GPT-6 Astra / Extra High, selected for durable initialization and exclusive ownership. Independent review is separate and read-only.

Status: source frozen; functional app-host tests, the director-ratified strict retained-entry check and both Release builds **PASS**. The earlier full app-host run passed functionally but **failed its original default-container guard**; that failure remains preserved below. Independent final closure and director acceptance are pending. No O4b source is released by this evidence.

## Identity and scope

- Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`. Intentional unpublished work; no upstream.
- Authority: exact [O4 amendment](261021_Owner_First_O4_Sequencing_Amendment_v1.0.md) `e58ca5466a7d95dc367415106f0f8a0310eac71643afd75d699456c407314867`; director accepted O4p source80 `d2906f11be7e1c602bde308b80938c9b4e9fd6d28c2a963fd980a5c042c4aaf8` and explicitly released O4a only.
- New `PadelStrokeLab/OwnerPhoneBootstrap.swift`: **181 production lines**, within the 250-line cap. New `PadelStrokeLabTests/OwnerPhoneBootstrapTests.swift`: **298 lines**, 16 test functions with parameterized cases. No other source, test, dependency, project, signing or configuration file changed.
- All **80 accepted O4p inputs remain exact**; the new source inventory has 82 entries. Accepted core245/19 evidence therefore carries forward; no changed Core input is covered by stale evidence.
- No app/UI adoption, connectivity activation by bootstrap, remote Start, Health acquisition, guest admission, Git publication, physical-device installation, erase or uninstall occurred. App-host installation on the explicitly reserved simulator is recorded separately from physical installation and retained data.

## Implemented boundary

The explicitly nonisolated, non-Sendable bootstrap privately owns P1, O3b/O2 and one locked witness. It implements the ratified pending→real store initialization→ready ordering, exact ≤128-byte format, no-follow/single-link checks, canonical base and live namespace/witness identity checks. Both actual checked store APIs run before and after successful or throwing bodies. Integrity failures poison; healthy domain errors preserve their original meaning and saved fences. Store handles must remain inside the synchronous closure.

The witness is deny-only and adds no authority, repair or cleanup policy. Existing store recovery remains delegated. Whole-container deletion/reinstall removes all local evidence; this package cannot recover it or restore consent. App adoption and physical durability remain unproved.

## Tests and exact source

The new tests use unique canonical temporary folders and actual P1/O3b constructors. They cover healthy fresh/reopen with unchanged raw sentinel bytes and no authority; faults after actual pending+parent synchronization, P1 initialization and channel initialization; pending/partial/version/canonicality/epoch/oversize errors; each missing/corrupt namespace and total triplet loss; existing namespaces without a witness; foreign channel role/epoch; concurrent owners; symlink/hardlink/directory/FIFO witnesses; forbidden/symlink bases; base/witness/namespace replacement; same-inode byte tampering; and sticky rejection after restoration.

Post-body tampering covers **P1, O2, O3b journal and witness × successful or throwing body**. A real pending enrollment/conflicting withdrawal exercises durable `intentOutstanding` fence retention through enrollment mirroring and later explicit withdrawal resolution. A separate host test verifies the actual isolation argument and the existing model's synthetic-mode selection. Review expanded these tests before the exact source freeze; no frozen predecessor assertion was weakened.

Private root: `/Users/mschlunegger/Library/Developer/Xcode/DerivedData/PadelStrokeLab-OwnerFirst/`.

| Artifact | SHA-256 / purpose |
| --- | --- |
| [O4a source82](261021_Owner_First_O4a_Source_v1.0.sha256) | `e1740faaa6a217d2f650d30635735db2db92f7792b6c316e6a495a5aea4f94fe` |
| `O4a/03-source.sha256` | Exact private manifest copy |
| `Checkpoints/04a-o4a-source.tar` | `3a9311116f18e4fd3defc5b2842f16cd7024df0bfbd90a0dc704d128fa09e25f`; source and embedded manifest |
| `O4a/evidence.sha256` | `0d458206aca00d83f40708618e6ba3fd7e5261bd7e2261b9f6efd0c735ef9b8a`; 389 entries including every retained result-bundle file |
| `O4a/03-isolated-host.xctestrun` | `93214c581d9044d22db0a0351d977112a650d0971c2bbd07c575191a8c097db1`; exact copy of executed generated runner |

Production SHA-256: `313dc2681ddd8b52b360166b2775cdb8c6340cc307cac6876cd7c1f6a0dc32df`. Test SHA-256: `cbedf5a705212b1303148ab2568033b648f64f60dfacb0dc35ae3984151e0c73`.

| Private O4a run | Result |
| --- | --- |
| `01-tests-first-red.log/.xcresult` and `01-tests-first.swift` | Expected missing-bootstrap/type-dependent stage compile failure, before implementation; original test source preserved |
| `02-build-for-testing.log/.xcresult` | **PASS**; final source/tests compiled before freeze/runtime |
| `04-frozen-app-host.log/.xcresult` | **Functional PASS — 30 tests / 4 suites, 1.700 seconds**; bootstrap suite 1.259 seconds; original default guard **FAIL** |
| `05-frozen-phone-release.log` | **PASS**, iPhone Release, generic iOS Simulator |
| `06-frozen-watch-release.log` | **PASS**, Watch Release, generic watchOS Simulator |
| `07-enumeration.log`, `07-selected-tests.json`, `07-selection-verification.json` | Exact authorized selection: 29 enabled functions, all 16 bootstrap functions included; exactly one default-write test disabled |
| `08-frozen-isolated-app-host.log/.xcresult` | **PASS — 29 tests / 4 suites, 1.545 seconds**, unchanged frozen source; retained-entry guard **PASS** |

Both Release logs contain four existing App Intents metadata-extraction warnings in total, zero error diagnostics. The test-build log contains three existing metadata-extraction warnings. Simulator framework/XPC diagnostic messages remain in the raw runtime/enumeration logs; no test failure or crash is hidden. The enumeration command produced its default result bundle outside the package root; an exact `07-enumeration.xcresult` copy is preserved here and its original logged path is retained, not deleted.

## Preserved guard failure and corrected selection

The original guard captured entry sets, mode, inode, mtime and regular-file size/SHA-256 for both devices' default `Documents`, `Library/Application Support` and app preference plist. It did not capture atime/ctime/xattrs or all transient activity. Runtime04's host isolation argument worked, but the selected frozen `RecordingLibraryTests/defaultAppContainerCanWriteInspectAndAnnotate()` directly calls `RecordingPaths()` (lines190–203) and creates/removes its synthetic default-root recording. Including that test was an isolation-selection mistake.

`03-default-containers-before.json`, `…-after.json`, and `…-diff.json` preserve the **failed guard**: phone raw/notes directory mtimes changed, and simulator installation relocated the phone container path. All captured retained-file entries/content and all Watch entries matched. This does not mean there were no transient writes. No timestamps were restored or evidence discarded.

The director explicitly authorized excluding only `PadelStrokeLabTests/RecordingLibraryTests/defaultAppContainerCanWriteInspectAndAnnotate()`. Enumeration verified29 selected functions, including all16 bootstrap functions; independent review compared actual04/08 result IDs. Runtime08 passed29/4. `07-default-containers-before.json`, `…-after.json` and `07-default-container-verification.json` prove identical protected entries across enumeration/runtime08. Phone container-path relocation is reported separately; Watch path stayed identical. The original30-test pass and failed guard remain recorded. No source/assertion changed and no automatic retry occurred.

## Runner, commands and remaining limits

Native Device Hub accessibility access was verified before both test periods. Tests used only reserved iPhone `2CE85F58-306B-49ED-8AC2-CA9D78A45F2A`, with paired Watch `91757361-AEA2-41D8-9C4F-6DE5FF6365DA` protected by fingerprints. Parallel simulator testing was disabled; no UI test executed. The generated private runner's documented `CommandLineArguments` field targets the phone app host and contains the existing synthetic-mode argument; the installed `xcodebuild.xctestrun(5)` documentation defines that mechanism. No frozen app entry point or build setting changed.

All Swift/Xcode commands set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, using approved Xcode27.0 `(27A266a)` and OS27 SDKs. Runtime used `xcodebuild test-without-building -xctestrun <OwnerFirst>/O4a/AppHost/Build/Products/O4a-Isolated.xctestrun -destination 'platform=iOS Simulator,id=2CE85F58-306B-49ED-8AC2-CA9D78A45F2A' -parallel-testing-enabled NO -only-testing:PadelStrokeLabTests`; runtime08 added the exact `-skip-testing:…defaultAppContainerCanWriteInspectAndAnnotate()` identifier above. Enumeration added `-enumerate-tests -test-enumeration-style flat -test-enumeration-format json`. Explicit runtime/build result bundles and complete commands are retained in their logs.

Release builds used the project and corresponding phone/Watch scheme, `-configuration Release`, `-destination 'generic/platform=iOS Simulator'` or `'generic/platform=watchOS Simulator'`, separate `<OwnerFirst>/O4a/PhoneRelease` / `WatchRelease` derived-data roots, and `CODE_SIGNING_ALLOWED=NO build`.

After all verification, every current/archive source entry and embedded manifest matched, all80 predecessor inputs remained exact, and `git diff --check` passed. No automatic retry occurred: runtime08 was a separately ratified isolation-selection correction with unchanged production/test source. Host fixtures and fault hooks prove the tested logical/storage boundaries, not physical power-loss behavior, paired delivery, sensor capture, background operation, battery or final user-facing readiness. O4b lifecycle persistence remains a separate design/release gate.
