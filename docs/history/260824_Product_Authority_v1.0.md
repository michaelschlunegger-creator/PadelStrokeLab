# PadelStrokeLab Product Authority

## Canonical product and design artifact

- **Document:** `Padel Performance App - Product Requirements, Scope of Work & Design Bible`
- **Document ID:** `PSA-PRD-001`
- **Version:** `2.0 - Red-Team Reviewed`
- **Date:** 2026-08-24
- **Repository artifact:** [`product/Padel_Performance_App_Product_Requirements_Design_Bible_v2.0_REDTEAM.pdf`](product/Padel_Performance_App_Product_Requirements_Design_Bible_v2.0_REDTEAM.pdf)
- **SHA-256:** `939c5858420124a4fe3753e3812c7ad594f3a2755c7225b7f2ebe6c13238af25`
- **Length:** 67 PDF pages (title page plus 66 numbered content pages)
- **Owner status:** Adopted on 2026-08-24 as the canonical product, requirements, UX, visual-design, data, architecture, AI, validation, and delivery guide for PadelStrokeLab.

The PDF is authoritative and must remain byte-for-byte unchanged at this version. This Markdown file records adoption, precedence, known current-state mismatches, and future amendments; it does not replace the PDF.

## Owner amendment: mandatory platform baseline

Owner decision recorded 2026-08-24:

- Every PadelStrokeLab app package, including Phase 0 feasibility, must build against the iOS 27 and watchOS 27 SDKs.
- The iPhone and Apple Watch deployment targets must be iOS 27 and watchOS 27 respectively.
- Xcode 26.5 and the iOS/watchOS 26.5 SDKs are not an authorized implementation, build, test, or evidence fallback.
- Implementation may begin only after an approved Xcode 27 toolchain is installed, selected, and verified locally.

This amendment resolves the Design Bible's platform baseline as a mandatory acceptance criterion. It does not claim the current generated project already satisfies that criterion.

## Precedence and interpretation

1. `ENGINEERING_GOVERNANCE.md` controls process, gates, evidence, and Git actions.
2. The Design Bible controls approved product behavior and design intent.
3. `GATE_CARD.md` controls the current bounded package.
4. Exact repository code and verified tests/physical evidence control claims about what is actually implemented or proven.

Every mandatory statement in the Design Bible is an acceptance criterion unless explicitly identified as a candidate, example, future option, target pending validation, or open decision. No feature is `ready`, `safe`, `validated`, `premium-complete`, or equivalent until its applicable criteria and evidence gates are satisfied for the exact code state.

## Adoption review

- Complete text extraction and page-by-page visual inspection found no unreadable, clipped, overlapping, malformed, or missing-page content.
- The high-rate Core Motion premise is supported by Apple's workout-centric `CMBatchedSensorManager` guidance: up to 800 Hz accelerometer and 200 Hz device motion, delivered in roughly one-second batches on supported Watch hardware.
- The cited padel study and tennis-wrist study support the feasibility hypothesis, but neither proves that a wrist-worn Apple Watch can classify padel contact quality. The document correctly requires a physical Phase 0 GO/NO-GO study.
- The iOS/watchOS 27 and Apple Intelligence direction is current but remains subject to SDK, entitlement, device, region, language, quota, and shipping-platform revalidation.
- No product feasibility, scoring accuracy, battery, latency, sync, or production-readiness claim is established by adopting this document.

## Current-state mismatches and unknowns

| Item | Status | Control |
|---|---|---|
| Design Bible and owner decision require iOS/watchOS 27 for every phase, while the generated targets and installed Xcode are 26.5. | `BLOCKED` for implementation until the local toolchain is corrected. | No 26.5 exception is authorized. Install and select an approved Xcode 27 toolchain, verify the iOS 27/watchOS 27 SDKs, then change both deployment targets in an approved non-main package. |
| Apple Watch Ultra 2 and compatible iPhone are named as primary validation hardware. | `UNKNOWN` until physically reconciled. | Record exact device models, OS versions, pairing, fit, and capability results before physical testing. |
| Runtime availability of high-rate accelerometer/device motion. | `UNKNOWN` until tested on the target Watch. | Capability checks and actual received rates are mandatory evidence; model names alone are insufficient. |
| Watch-only separation of air swings, impacts, and centre/off-centre contact. | `UNKNOWN`. | Execute Design Bible Sections 36 and 62 without hidden retries before any consumer scoring work. |
| Contact Quality formula, thresholds, calibration protocol, and final stroke classes. | `OPEN` by design. | Resolve only from retained evidence and approved decisions after feasibility. |
| Foundation Models/PCC availability and entitlement at implementation/release time. | `UNKNOWN`. | Reverify against the exact SDK and runtime; core measurement and summaries require deterministic fallbacks. |
| Final product name and brand. | `OPEN` by design. | `PadelStrokeLab` remains the prototype name until an approved product decision. |

## Change control

- Never overwrite this version of the PDF.
- A revised Bible receives a new versioned filename and SHA-256, followed by owner approval and updates to this authority record, governance, Gate Card, tests, and affected evidence.
- Product or design decisions that clarify but do not revise the PDF must be recorded as explicit amendments here or in a repository document linked from here.
- Chat messages, mock-ups, generated content, implementation shortcuts, and AI output do not override the adopted artifact.
