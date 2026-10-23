# Owner first build O4 sequencing — independent review v1.0

21 October 2026. Independent Codex review in the assigned Astra Extra High role, justified by live storage integrity, bootstrap ordering and authority boundaries. Read-only review; this authorized report is the only file written for the amendment review. No production/test/configuration edit, build/test, Git mutation or device action was performed.

**Verdict: CLEARED FOR DIRECTOR RATIFICATION AND SEQUENTIAL RELEASE. The next eligible release is O4p only.** This is a planning/scope review, not implementation acceptance, G6, a merge verdict or physical readiness. O4a and O4b require their own later releases.

## Exact reviewed state

- [Final sequencing amendment](../testing/261021_Owner_First_O4_Sequencing_Amendment_v1.0.md), SHA-256 **`e58ca5466a7d95dc367415106f0f8a0310eac71643afd75d699456c407314867`**.
- Repository `/Users/mschlunegger/Documents/GitHub/PadelStrokeLab`; branch `feature/guided-padel-setup`; accepted HEAD `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e`; unpublished working-tree review.
- Accepted O3c source inventory: **80 entries**, manifest SHA-256 **`94c51aca7a4f72669935eb7a17394f54900f6704fbe908ddc21ed9c7c6a4fc15`**. Every current source/test/configuration entry independently matches. Read-only `git diff --check` returned zero.
- First-build contract remains SHA-256 `f7666a8d73d5e11fa786571f294b9837d96d3768b30d9318b578ab8d762f706f`. Its section 3 explicitly requires a distinct companion practice identity.

| Stage | Production scope and hard cap | Release condition |
| --- | --- | --- |
| O4p | Existing `PracticeSetupStore.swift`, at most 10 changed lines; existing matching Core test file only | Focused P1 tests, fresh full core and both Release builds, exact freeze/review/director acceptance before O4a |
| O4a | New phone `OwnerPhoneBootstrap.swift`, at most 250 lines; named new app-host tests | Actual bootstrap fault/ownership tests, both Release builds, exact freeze/review/director acceptance before O4b |
| O4b | Original five phone setup/UI paths, at most 1,440 changed lines; named host/UI tests and declared affected navigation test | Separate concrete lifecycle design and implementation release, then its required test/build/evidence/review gate |

The original combined **1,700 changed production-line cap is preserved without pooling**. Only O4p's two named Core paths may change in that stage. No implicit Core/Watch/configuration exception or extra journal is authorized.

## Resolved findings and remaining boundary

**Checked P1 reads are necessary.** The reviewer inspected the existing private `checkLive()`: it validates the named directory, held lock identity, allowed entries and exact backing bytes, with sticky poisoning on failure. Cached `snapshot` bypasses those checks. The proposed public `checkedSnapshot()` only calls that existing validator and returns the existing snapshot. It adds no parser, write, repair, grant or acceptance behavior. Required tests prove read immutability, correct state after real saves and rejection/sticky poison after independent tampering. Fresh core evidence is mandatory because P1 changes.

**Bootstrap owns real initialization before readiness.** The deny-only bounded witness is synchronized as pending before namespace creation, then becomes ready only after actual P1/O3b initialization. The bootstrap owns one P1 and one O3b instance; O3b privately owns O2. Canonical base, named witness and all three namespace identities are checked, together with P1's new checked read and O3b's checked snapshot. Pending, partial, missing, detached or ambiguous state cannot trigger repair or reinitialization. Whole-container deletion/reinstall remains an explicit detection limit.

**Routine body rejections must remain recoverable.** `withStores` performs post-verification after success and throw. Bootstrap integrity/I/O/ownership failures poison bootstrap; body errors retain the accepted stores' own poison semantics. A healthy `intentOutstanding` may persist a local privacy fence and be rethrown without disabling later explicit resolution. Tests must cover both healthy domain rejection and tamper-then-throw. Nonescaping access/Sendable results do not replace the O4b obligation to keep both mutable stores private to its serial owner.

**The earlier identity clearance is withdrawn.** The reviewer incorrectly accepted amendment `747300f3618e4b4b98434615e88492296093d103f0aa2c6e70524aa171e4a196` with practice/preparation ID reuse. The director identified the conflict with first-build section 3. Final amendment `e58ca546…` changes exactly that paragraph: `practiceID` is independently created and separately retained from P1 `preparationID`; edits retain the practice ID, preparation revisions/generations advance independently, and a new practice after End uses a fresh practice ID. Aliasing or deriving the practice identity by reinterpreting P1 identity is not permitted.

That correction does not yet prove O4b's complete lifecycle durability. **O4b remains held until concrete distinct-ID, current-versus-next, relaunch and End behavior is reviewed.** Existing P1/O3b facts must not be relabeled as lifecycle facts they do not store. If a required fact cannot be represented safely through accepted APIs, its persistence requires a separate explicit review before dependent implementation. No new journal or lifecycle authority is implicitly granted. O4p and O4a themselves have no practice lifecycle authority, so this later design gate does not block their sequential review.

The amendment's prohibition on new cleanup/repair policy is read alongside its explicit use of accepted P1/O3b reopen recovery. Those frozen constructors may synchronize, replay committed work or remove a validated P1 temporary. Bootstrap must not claim that delegated reopen recovery never writes, and must add no independent reset, deletion or repair mechanism.

**Next action:** director ratifies this exact amendment and releases O4p only. Each later stage remains separately gated.
