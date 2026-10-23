# Padel Master — product and first-build scope

The app is an iPhone-first padel companion with an Apple Watch worn on the racket arm. The current development candidate collects evidence for an owner-led forehand/backhand feasibility study. Minimum platforms are iOS 27 and watchOS 27; the physical baseline is iPhone 15 Pro and Watch Ultra 2.

## Authority

[Product authority and owner amendments](PRODUCT_AUTHORITY.md) govern the retained [App Specifications PSL-SPEC-001 v1.1](product/261016_App_Specifications_PSL-SPEC-001_v1.1.txt). The snapshot remains immutable. The approved [forehand/backhand contract](testing/261021_Owner_Forehand_Backhand_First_Build_Contract_v1.0.md) narrows the first build and defines its acceptance criteria. The seven-stage roadmap remains in the specification; this candidate does not implement every later stage.

## Current workflow


1. On iPhone, choose **Let's Play**, review owner/motion consent and optional heart rate, then explicitly answer **Which hand holds your racket?** and **Which wrist is your Watch on now?** Matching sides show only a short confirmation; different sides show the move-to-racket-wrist, system wrist/crown and fit guidance. Select manual forehand or backhand and prepare on the paired Watch. Neither side is an assumed confirmation; saved unusual handedness remains explicitly correctable.
2. On Watch, begin the practice, then complete the brief placement/orientation/fit check before each set. Start recording explicitly on Watch. Confirm the actual watchOS wrist/crown settings and wear Watch on the playing arm.
3. Record real wrist accelerometer and device-motion streams. Pause/resume within a set, stop and wait for durable saving. Each set permits up to 120 active seconds; a practice permits up to 20 sets within 30 minutes.
4. Transfer retained data to iPhone using verified receipts. Review wrist-signal charts, coverage, interruptions, optional heart rate and observed recovery. Missing or excluded readings remain unavailable.
5. Add separate clean/mishit/uncertain/air-swing/other-movement reference labels. Inspect export scope before sharing. Whole-practice deletion reports local completion and any pending peer work honestly.

The selected stroke is an intended type, not automatic recognition. Labels are owner assessments, not independent ground truth. No validated contact-quality score, ball speed, court accuracy, body acceleration, GPS distance, VO2-max measurement or medical recovery claim is made.

## Acceptance and limits

The development gate requires deterministic logic/storage/transport/deletion coverage, phone and Watch UI/accessibility checks, matching Release and signed products, independent review and exact-source CI. Real sensor fidelity, permissions, wrist-down/background behavior, offline delivery, retained export integrity and battery require the [physical runbook](testing/261021_Owner_Forehand_Backhand_Physical_Runbook_v1.0.md). Build success does not prove those behaviors.

The initial experiment uses the experienced owner and repeated separate-session self labels; a paid coach is not mandatory. Guest/watch sharing, 5–10-player TestFlight collection, additional strokes, steps/distance/GPS, generalized classification, grounded Apple Intelligence explanations and social/community/ranking/chat/teaming/booking belong to later reviewed increments. Guest data must never be attributed to the owner's account. Apple Intelligence must explain validated evidence with a deterministic fallback, never manufacture measurements.

Black, turquoise and white are the current presentation direction. iPhone owns detailed setup and statistics; Watch remains the sensor/logger and short-results terminal. No App Store/TestFlight release or merge is authorized by development installation.

Customer-facing setup should be logical and brief: ask distinct necessary
questions, show the next necessary action, and present detailed instructions only
when the player's answers make them relevant. Keep essential safeguards concise;
do not turn routine successful states into additional setup work.
# Recording privacy corrections — 22 October 2026

The approved first-build scope is unchanged. On Watch, **Delete retained data** confirms complete-practice deletion for verified owner records, including sibling sets, motion, heart-rate telemetry, notes and attributable transfer staging; paired cleanup remains pending until acknowledged. Truly context-free legacy recordings retain copy-only deletion. Damaged or conflicting owner evidence keeps data and reports incomplete deletion rather than guessing its scope.

Full motion-consent withdrawal immediately disables owner analysis and export, including during pending/offline or failed consent persistence. Identity-bound metadata remains discoverable so the owner can delete retained practices after relaunch. Explicit valid re-consent can restore analysis without rewriting original practice identities. See the [verification record](testing/261022_Privacy_Readiness_Corrections_Verification_v1.0.md). Automatic stroke recognition and quality prediction remain unvalidated future work.
