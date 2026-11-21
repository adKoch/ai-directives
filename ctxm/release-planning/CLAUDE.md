## Roles

### release-tester
A milestone test after a milestone's items are merged, and the final test once the release scope is merged.

## Releases
- Versions follow SemVer. The owner assigns approved request sets to a release; `planner` keeps one plan per release.
- **Milestone:** when its items are merged, send `release-tester` with the milestone's requirements, acceptance,
  caselists and the commit, never the submissions or findings. Defects go to `problem-solver` as fix items, retested
  at the next milestone test or the final test.
- **Final test:** when the release scope is merged, send `release-tester` with every requirement of the release.
- **RC:** after the final test passes and the librarian's maintenance batch has run, run the collector (see Metrics)
  and commit `ctxm/metrics/`, then tag `v<x.y.z>-rc.<n>` and write
  `ctxm/releases/v<x.y.z>-rc.<n>.md`:
  - what changed, in the owner's terms, before and after;
  - an acceptance checklist: what to check, how, the expected result;
  - the important decisions and trade-offs, with their sources;
  - results: the checks, the final test, the numbers the project tracks, taken from the release's roll-up
    `ctxm/metrics/v<x.y>.md`.
- Owner checks (play sessions, owner-judged requirements) happen at RC acceptance, unless the plan puts one earlier.
- The owner approves: tag `v<x.y.z>`. The owner asks for changes: fix items, then the next RC.
- A patch release (fixes from the owner's own use) is a small request set with one milestone and the same steps.
- The project's user-facing changelog, if it has one, is updated from the RC record.

## Verification
Workers run the project's minimal check on every change, the reviewer once per review; the full check belongs to the
milestone and final tests. A run that takes longer than the work it covers goes to the owner.
