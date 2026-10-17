# PadelStrokeLab Agent Instructions

## Authority and startup

At the start of every task, read this file, `ENGINEERING_GOVERNANCE.md`, `docs/PRODUCT_AUTHORITY.md`, and `GATE_CARD.md`. Before product, architecture, design, implementation, testing, or readiness decisions, read the applicable sections of the current approved specifications identified by `docs/PRODUCT_AUTHORITY.md`. Then perform G0 and reconcile:

- repository path, branch, base, HEAD, upstream, and remote HEAD;
- ahead/behind state, worktree changes, and changed-file scope;
- active PR and handover state, if any;
- evidence that remains valid for the exact code state.

The repository and its current Git state are authoritative. Chat history is context only. If a required fact is unavailable, mark it `UNKNOWN`; never infer a protected, safe, tested, or ready state.

## Project scope

PadelStrokeLab is an iPhone app with a paired Apple Watch app. `PSL-SPEC-001 v1.1` (App Specifications, 16 October 2026) is the current product authority, with the retained mandatory iOS/watchOS 27 platform decision. The older `PSA-PRD-001 v2.0` PDF remains immutable historical design reference and cannot override v1.1. The first feasibility work uses the owner’s normal practice and self-reference labels; no paid coach or large participant study is mandatory. Proposed defaults and open decisions are not approvals. See `docs/PRODUCT_AUTHORITY.md` for precedence and exact source identity. Device ownership, sensor authority, transport semantics, persistence, and user-visible behavior must also be bounded in the active architecture and test-contract gates before production implementation.

iOS 27 and watchOS 27 are mandatory for every phase, including Phase 0 feasibility. Do not implement, build, test, or collect evidence with Xcode 26.5 or the iOS/watchOS 26.5 SDKs. Before production or test changes, verify an approved Xcode 27 toolchain is selected and both 27 SDKs are installed.

Core Motion capture, WatchConnectivity, background/lifecycle behavior, concurrency, data integrity, export/evidence, permissions, notifications, and physical feasibility are Risk Level 3 when failure can invalidate the experiment or misrepresent captured data.

## Required sequence

Authority → Risk map → Test contract → Implementation → Local automation → Clean CI → Independent review → Physical iPhone/Watch evidence → PR/merge → Closure

Do not skip a gate or transfer evidence to a changed code state. Simulator results cannot prove physical sensors, Watch connectivity, background behavior, battery behavior, haptics, sound, or on-watch usability.

## Change controls

- Never edit `main`. Work on a verified, scoped branch.
- Never commit, push, merge, delete branches, open a PR, or change remote state without explicit user approval.
- Define tests before production changes and add regression coverage for corrected behavior.
- Test production paths; test seams may isolate hardware or connectivity only when production defaults remain unchanged.
- Never weaken assertions, safety rules, or product behavior to make tests pass.
- Do not use automatic retries to conceal intermittency. Preserve every failed command, test, build, CI run, or physical observation as failed evidence.
- Split work before implementation if it exceeds eight production files, 2,500 changed lines, or two Risk Level 3 domains.
- Keep implementation and independent final review separate. The final reviewer must review only and must not modify files.

## Evidence and verdicts

Evidence is valid only for the exact code state that produced it. Production, test-seam, dependency, build-setting, rebase, merge, or conflict-resolution changes invalidate affected evidence.

Risk Level 3 work cannot be declared merge-ready without relevant physical iPhone and Apple Watch evidence. Final independent review must return exactly one verdict: `SAFE TO MERGE`, `SAFE WITH NON-BLOCKING NOTES`, or `BLOCKED`.

Keep `GATE_CARD.md` current with authority, scope, invariants, failure paths, evidence, blockers, and one next action.
