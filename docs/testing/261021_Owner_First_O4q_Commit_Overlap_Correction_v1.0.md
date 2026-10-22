# Cancellation commit-overlap correction

21 October 2026. Instrumented full05 reproduced the same negative-probe failure (267/20,1 issue). Commit entered at2.119ms, its five-second gate timed out at5010.619ms, and cancellation was not submitted until5010.666ms. The100ms timer fired at5113.573ms versus its5110.687ms target. This establishes that the intended overlap had ended before cancellation; it does not demonstrate a production cancellation-lock bypass or a late timer in this reproduction.

Independent Sol review traced synchronous commit blocking within the handler task and recommended the following test-only correction; root ratifies it for Astra implementation. Only existing `Packages/PadelCore/Tests/PadelCoreTests/OwnerPreparationTransportTests.swift` may change, ≤70 added correction lines against frozen D. All production code and other81 inputs remain frozen.

Have the handler await a checked throwing continuation completed exactly once by a separately owned `.userInitiated` Foundation.Thread executing the real `work.commit` and existing closure. The handler must remain alive until the worker finishes, then follow the existing exit gate. Use a separate `.userInitiated` cancellation thread; record/signal its start immediately before the real cancellation call and await that start before the original100ms negative probe.

Preserve the original five-second commit wait,100ms probe and all existing ordering, drain, response, cleanup and count conditions. Additionally assert that the commit wait succeeded through explicit release, so its fallback cannot masquerade as the intended overlap. Retain diagnostic traces and the generic timer helper's existing scheduling/semantics. No timeout increase, production seam, fake commit/cancel implementation or early handler return is authorized.

The failing05 run supplies the regression reproduction. Root freezes the correction and runs the full suite once; Sol checks source and measured overlap. Preserve every prior failure and distinguish observation from executor-policy assumptions. Relevant app-host/Release checks and final review still precede acceptance.
