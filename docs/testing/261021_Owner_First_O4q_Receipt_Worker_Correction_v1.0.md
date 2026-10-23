# O4q receipt-worker correction

21 October 2026. Owner-authorized blocker correction, independently challenged by GPT-6.1 Sol High; root ratifies the following test-only change for Astra Extra High implementation.

Instrumented full run03 reproduced the first receipt barrier failure:267 tests/20 suites,1 issue, exit1. The importer was submitted at23.945ms, began at19321.597ms and reached beforeReceipt at19329.261ms. Submission-to-worker delay was19297.652ms; actual work to receipt took7.664ms. Later contention/completion/deletion checks passed. This identifies shared-global-queue scheduling delay in03; untraced04 is preserved without claiming its exact cause proved.

Release only existing `Packages/PadelCore/Tests/PadelCoreTests/RecordingLocalCopiesTests.swift`, at most20 added correction lines against frozen B. Replace this test's importer and deleter `DispatchQueue.global().async` submissions with two separately owned `Foundation.Thread` workers, each `.userInitiated` QoS set before `start()`. Distinct custom dispatch queues were rejected as a guaranteed remedy because they still use shared libdispatch worker pools. Explicit threads remove that submission dependency; actual validation is still required.

Preserve all original10-second waits, success/error conditions, actual lock-contention ordering, completion signals, deletion/no-resurrection checks, phase tracing, source lifetime and cleanup. No production change, timeout increase, weaker assertion, public seam or extra worker is allowed. Corrected channel source/tests and all other manifest inputs stay frozen. The failing03 run supplies the regression reproduction; do not add implementation-mirroring tests.

After correction freeze, root runs the same full suite once and inspects the trace plus all assertions. Preserve every earlier failure. A passing corrected run supports this harness fix, not physical data or general timing claims. Then complete affected isolated app-host and both OS27 Release checks, final exact-source evidence and independent review. Any failure requires diagnosis, not automatic retries. O4b and physical readiness remain held pending the complete candidate.
