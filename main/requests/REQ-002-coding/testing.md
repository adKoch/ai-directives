# REQ-002 coding: testing (superseded 2026-11-16 by request.md and REQ-004 classification.md; kept as history)

## Few tests
- Unit tests 80:20 or 90:10: only obscure logic. Each test starts with `catches: <the failure it catches>`.
- No tests that check docs. Benchmarks report, never fail.
- Domain templates add their kinds (e.g. golden replays for games).

## Tags
- A closed tag list in `tests/tags.toml`: `unit`, `regression` (with `def:DEF-nnn`), `bench`, plus domain kinds.
  The area comes from the test's folder.
- Only the **reviewer** assigns tags; the manifest is its only code-side write, enforced by a hook.
- Workers submit candidate tests; candidates run in the worker's own checks.
- Untagged means **dormant**: kept as documentation, not run. Dormant tests get a parse-only check and a
  once-per-release report-only run.
- A test untagged at the approval of release N and still at N+1 is deleted by a script; the release record lists it.

## Failure history
- The test runner logs every run: commit, branch, item, role, tests selected, failed, messages. The log stays local.
- `scripts/test-history.sh` queries it by test, branch or area, with the files changed since the last pass.
- Failures are classified: `new` (failed when first written; not counted), `caught`, `edited`, `flaky`,
  `regression on main` (an alarm to main).
- Counts (`caught`, `flaky`, `last_caught`, `defects`) are committed in the manifest.

## Test tampering (blocking unless the item requires it)
Removed tests or assertions, skip markers, changed expected values or golden files, wider tolerances or timeouts,
smaller test sizes, test-mode special cases in product code. The inspector reads for it; the reviewer checks it.
