# PadelStrokeLab Engineering Governance

## 1. Purpose

This document governs changes to the PadelStrokeLab iPhone and Apple Watch prototype. It protects code-state authority, experimental evidence, data integrity, and physical-device conclusions.

## 2. Authority order

1. Exact local repository and Git state during Mac implementation establish what code and evidence actually exist.
2. This governance document controls process, gates, evidence, and Git actions.
3. The Current approved App Specifications and explicit owner amendments identified by `docs/PRODUCT_AUTHORITY.md` control product behavior and design intent.
4. The active `GATE_CARD.md` controls the current bounded package; approved architecture and test contracts refine its execution.
5. Pushed Git branch and exact HEAD are authoritative when work transfers to another device or environment.
6. Conversation history is non-authoritative context.

Production code is authoritative for runtime behavior. Tests and documents describe intended behavior but cannot overrule contradictory production behavior or missing evidence.

The current authority is `PSL-SPEC-001 v1.1`. Its approved direction supersedes conflicting older product assumptions; proposed defaults and open decisions still require confirmation before dependent work. Versioned reference artifacts remain immutable at their recorded checksums. Revisions require a new versioned artifact, owner approval, and re-evaluation of affected architecture, tests, and evidence. The retained v2.0 PDF is historical reference, not an additional coach or study gate.

The owner-approved platform baseline is iOS 27 and watchOS 27 for all phases, including feasibility work. Xcode 26.5 and the iOS/watchOS 26.5 SDKs may be inspected only; they cannot produce implementation, build, test, or product evidence for this project.

## 3. Current product boundary

The generated Xcode project contains:

- `PadelStrokeLab`: iPhone app target;
- `PadelStrokeLab Watch App`: paired watchOS app target;
- unit and UI test targets for both platforms.

The final device roles, sensor sampling contract, session authority, transfer protocol, persistence model, and export format are `UNKNOWN` until approved at the architecture gate. No generated placeholder UI is a product decision.

## 4. Risk classification

- **Level 1:** documentation, repository metadata, and changes with no runtime effect.
- **Level 2:** bounded UI or isolated logic with no safety, authority, or evidence-integrity impact.
- **Level 3:** sensor capture, timestamping, session authority, WatchConnectivity, pairing, background/lifecycle behavior, concurrency, persistence, evidence/export, permissions, notifications, or feasibility/readiness conclusions.

When uncertain, use the higher risk level. Risk Level 3 architecture, governance, blockers, beta readiness, and major handovers use Extra High reasoning. Bounded implementation, testing, and review may use High reasoning after the architecture and test contract are approved.

## 5. Gates

| Gate | Requirement | Exit evidence |
|---|---|---|
| G0 Authority | Reconcile repo, branch, base, HEAD, upstream/remote, ahead/behind, worktree, changed files, PR, Gate Card, and handover. | Exact state recorded. |
| G1 Risk and scope | Define risk domains, allowed/forbidden files, invariants, non-goals, and failure paths. | Approved bounded package. |
| G2 Test contract | Define production-path tests, regressions, expected failures, hardware limits, and evidence invalidation. | Approved tests before production changes. |
| G3 Implementation | Execute only the approved package on a non-main branch. | Scoped diff with no unrelated changes. |
| G4 Local automation | Run relevant tests, full suites without retries, Release builds, and clean-state checks. | Exact commands and results recorded. |
| G5 Clean CI | Run required CI on the exact pushed HEAD. | Clean, current CI evidence. |
| G6 Independent review | A new agent reviews committed HEAD only and does not edit files. | Required merge verdict. |
| G7 Physical devices | Validate relevant behavior on paired physical iPhone and Apple Watch. | Repo-labelled observations for exact HEAD. |
| G8 PR, merge, closure | Reconcile final state, merge only with approval, then verify main and close the Gate Card. | Merge and post-merge evidence. |

Any blocking full-suite failure blocks the branch. A changed HEAD invalidates the prior independent verdict. A rebase, merge, conflict resolution, dependency change, or build-setting change requires G0 and the affected gates again.

## 6. Git policy

- Bootstrap starts on a non-main branch based on verified `origin/main` because `main` must not be edited directly.
- The first local project/governance commit requires explicit user approval.
- All later work branches from verified clean `main`.
- Commits must be scoped and evidence must name the exact commit.
- Commit, push, remote creation, PR creation, merge, branch deletion, and release/tag actions each require explicit approval.
- Never hide user changes, rewrite shared history, or use destructive reset/checkout operations without explicit authorization.
- Generated user-specific Xcode state and build products remain untracked.

## 7. Implementation and review separation

For Risk Level 3 work:

1. Project direction approves architecture, scope, invariants, failure paths, and tests.
2. A bounded implementation agent changes only allowed files and collects local evidence.
3. After automation and commit, a new independent agent reviews exact HEAD. Review only; no file modifications.
4. Any post-review code change invalidates the verdict and requires affected gates again.

## 8. Physical feasibility

Simulator evidence is useful for deterministic logic and UI flow only. Physical iPhone and Apple Watch evidence is mandatory for conclusions about Core Motion fidelity, sampling continuity, WatchConnectivity delivery, background behavior, installation/pairing, permissions, battery impact, and watch ergonomics.

Physical instructions must use repository-derived labels and request one observable action at a time. Record device/OS versions, build identity, configuration, expected result, actual result, and captured evidence.

## 9. Completion standard

A package is complete only when every mandatory acceptance criterion is marked `VERIFIED`, `CONTRADICTED`, `UNKNOWN`, or `BLOCKED`; failures remain visible; evidence matches exact state; and the Gate Card names one next action. Risk Level 3 work is not merge-ready until G0–G7 are satisfied for the same code state.
