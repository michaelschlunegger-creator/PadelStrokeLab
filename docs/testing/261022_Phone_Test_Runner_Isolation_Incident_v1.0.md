# Phone test runner isolation incident and correction

22 October 2026. Local verification incident; no physical installation or collection. Branch remains `feature/guided-padel-setup`. This operational ratification releases only the correction and guarded verification below, not production changes or a data reset.

## Observed failure and root cause

The isolated frozen38-plus-diagnostic41 phone build42 and UI43 passed; Guard44 confirmed original protected defaults unchanged. For wider enumeration45, the director substituted build42's fresh generated xctestrun for the prior explicitly isolated runner without carrying its app-host launch argument. Independent review confirmed old `O4b-26-Isolated.xctestrun` target **PadelStrokeLabTests** had `--motion-statistics-fixture=unavailable`, while the generated runner had no arguments. Enumeration can launch the app host; it therefore entered the real default bootstrap path. This was an execution error, not a failing consent assertion or an O5 production change.

Guard46 failed before the proposed full regression run; no full47 execution occurred. Independent comparison of Guard44 to Guard46 found seven new phone default files plus their directories; every pre-existing regular-file size/SHA remained unchanged and no entries were removed. Watch entries were identical. The phone container path moved and the existing Application Support directory's modification time changed. The mutation is additive owner/setup bootstrap metadata; it cannot be described as original defaults preserved. Retain the enumeration, guard failure and all snapshots. Do not delete, restore or silently rebaseline the added files.

## Bounded operational correction

Copy the fresh runner to a uniquely named private xctestrun. Locate exactly one app-host target by **BlueprintName**, require the established early fixture argument on that target, and validate it before both enumeration and execution. Preserve the UI target and all other runner fields. UI tests continue to select their own per-launch fixtures. Record the corrected runner's hash and exact commands. No production, assertions, test selection or timeout changes are released by this correction.

Keep the original protected snapshot immutable and continue reporting its known deviation. Freeze snapshot46 separately as an incident checkpoint and compare future captures with it to detect any additional mutation. Passing this supplemental guard means only **no changes since46**; never report original defaults unchanged. Continue recording container path relocation separately from protected entry equality. Any further unexplained mutation blocks execution and requires diagnosis, not a reset or automatic retry.

The independent reviewer verified the correction scope and retained-data diff before this ratification. After validating the runner, one corrected enumeration and the required eligible full phone suite may run on the isolated41 source. Existing exclusions remain explicit: the default-container host test, performance test and generated launch tests are excluded pending O11. Match executed identifiers to enumeration; preserve every failure; no automatic retry.

The single consent diagnostic43 remains valid for its exact source and launch. Current live O5 remains unaccepted; formal current integration, publication/review and physical gates remain outstanding. Independent review must assess the correction/results before local O4b closure.
