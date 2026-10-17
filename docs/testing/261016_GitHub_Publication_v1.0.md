# Foundation GitHub publication evidence

16 October 2026, Asia/Dubai. Owner instruction: “use Github for saving the code etc.”

## Verified publication

- Repository: https://github.com/michaelschlunegger-creator/PadelStrokeLab
- Branch: `chore/project-governance`; upstream: `origin/chore/project-governance`.
- Implementation commit: `7ae8a9855a52251b588e7cc4cb7ab2aa1fd7ebd0`.
- Base and unchanged remote main: `f21bfab4dd6da9f96d7104bdfa3f06c5e4c92ea8`.
- Draft review: [PR #1](https://github.com/michaelschlunegger-creator/PadelStrokeLab/pull/1), base `main`, compare `chore/project-governance`.
- Git push succeeded. A separate `git ls-remote` read matched the implementation SHA; working tree was clean and upstream matched after push.
- Historical Drive archives remain preserved. No merge, tag, release, visibility change or deletion was performed.

## Test identity

All 22 manifest entries were rechecked before the implementation commit. The committed source fingerprint manifest SHA-256 remains `ae46545352968c0a6bd00f15df0aa01df26c53f8e2ecd9b475e4e71fcc27e0ca`.

The [local evidence record](261016_Foundation_Local_Evidence_v1.0.md) was collected before committing and applies to the identical source/configuration/test files in implementation commit `7ae8a9855a52251b588e7cc4cb7ab2aa1fd7ebd0`: 29 shared-core tests, both Release simulator builds, iPhone suite (seven executions) and Watch scheme (12 executions) passed. No retry-on-failure. Generated app tests mainly prove launch/smoke behavior; no physical conclusion follows.

Documentation-only publication follow-ups do not alter those tested files. Any future source, configuration, dependency or test change requires affected validation again. Independent review must use the final PR HEAD, including those documentation updates.

## Remaining gates

No GitHub Actions workflow or CI run exists on this branch; CI is not passed. A new independent review of committed HEAD is required. Physical installation, sensors, pairing, background behavior, battery and on-court evidence remain unverified. The PR stays draft; owner merge approval remains required.
