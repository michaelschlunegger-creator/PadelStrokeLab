# O8a tests-first local review — 22 October 2026

Explicit model routing: `gpt-6-astra`, Extra High, writes foundational code/tests; independent `gpt-6.1-sol`, High, reviews only. This is local test-contract adequacy, not formal G6, merge or physical readiness.

Frozen100-input tests04 manifest `c1b95365b1a710b817841516ceec0bb45e2dc36dffe9842b96f543d94d4b8a82`, archive `b73906e3833d7e81c798530125181f0914d32a76b30738acb178dfe23fe4b8fa`. All98 accepted O7 inputs remain unchanged. New BundleTests483 lines hash `0243974eb6ab1057c041a1fe8f279a5914e09f148ea026dec05639b23cfe4753`; ReceiptTests199 lines hash `e254697f4c298ebc504345d5415e13f7193fc99e7bfb91080fab829ade0ccec8`.18methods/39parameter-expanded cases proposed, none executed yet.

Independent review found one test gap: the first lost-completion test dropped an already confirmed publication. A narrow +8/-4-line correction now performs actual prepare, rename, drops the handle without confirmation, then requires an exact receipt on reopen before byte-identical retry/export. Independent review accepted the correction and found no other concrete test/API/scope blocker.

Core missing-interface red02 failed1/13.916s; changed-test red05 failed1/4.220s. Both logs retained under private `PhysicalReadiness1`. Diagnostics are missing new O8a types and dependent stage cases, with no unrelated existing-fixture/API error. All100 inputs remained unchanged through red05. These are compile-time red evidence; no runtime assertion pass/fail is claimed. Tests cover actual two-stroke raw/timeline/labels/retired contexts, finalized O6 snapshots, HR inclusion/absence/exclusion, private staging, integrity conflicts/revisions and readback.64/65components and256MiB cases are parser-boundary checks, not a valid256MiB roundtrip claim.

Root releases only new Core `OwnerPracticeBundle.swift` and `OwnerPracticeReceipt.swift`, combined1600production-line cap; approved tests/all existing source frozen. Heavy I/O precedes final publication; prepared descriptor-pinned rename must support O8b current-authority fencing. Current-authority races remain O8b obligations. No installation or publication was released.
