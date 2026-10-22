# A4 — Accessible note layout

Date: 2026-10-20. Branch: `feature/guided-padel-setup`. Baseline HEAD: `bc5e73d473dfbcd33fbb8196c1cafc5436ed9f3e` plus frozen source29 working changes.

Author: GPT-6 Astra Extra High; justified by the established presentation/accessibility review assignment. Independent Astra review cleared this bounded proposal and the Director ratified implementation before source edits.

## Observed problem

At simulator Text Size 11, the empty vertical note field clips its long prompt even when the row is fully onscreen. Entering a short synthetic word expands the field and is readable. Receipt36 records the blocker. The native evidence picker summary can abbreviate, while its menu exposes the full value.

## Exact amendment

Only the note block in `RecordingLabelEditor`, `PadelStrokeLab/RecordingDetailView.swift`, may change (at most 80 changed production lines):

- Put the exact instruction, “Optional note (up to 1,024 UTF-8 bytes)”, in persistent wrapping `Text`, using `PracticeTheme.secondaryInk(scheme)` and `.fixedSize(horizontal: false, vertical: true)`.
- Place the existing native vertical `TextField` below it in a leading `VStack`. Preserve `$draft.note` and the full accessibility name; use the short prompt “Add a note”, explicitly styled with the same secondary-ink token.
- Use `.lineLimit(1...)` to let editable content expand without a fixed height or font-size cap; the approved Xcode 27 build must verify this API.

Keep all validation, Save/Cancel behavior, UTF-8 limit, model/data paths, time fields, and A3 deletion bytes unchanged. No dependencies, settings, capture, connectivity, physical-device changes, Git publication, or icon work.

## Bounded verification

Freeze a source29-to-A4 diff and hash manifest. Build the affected Release product with the approved Xcode 27 toolchain. Run the existing `RecordingLibraryTests.appendEditUnmatchedAndRawImmutability` and `RecordingLibraryTests.explicitClockMatchAndRejectedAmbiguousIntervals` tests. There is no existing label-editor UI test; no test-file change is planned.

On the reserved iPhone simulator, verify empty and typed note content at ordinary Text Size 3 and maximum 11, including live 3→11 change, persistent instruction, usable native software keyboard, reachable Cancel/Save, and cancellation without saving. Inspect the actual empty Start/End fields at maximum size; do not infer their result from explanatory text. Protect the eight original fixture files and verify their hashes after final installation. Restore prior phone/Watch inspection settings and verify ordinary Release launches.

Evidence is simulator-only. Root owns the public evidence record and Gate Card. Independent final local review and restoration precede Theme A acceptance; Icon B remains held until explicit handoff.
