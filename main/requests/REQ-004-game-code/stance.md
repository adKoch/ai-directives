# REQ-004 stance sections

A few lines per file; each points to the project's docs (`wiki/README.md`) for details.

| File | Section adds |
|---|---|
| `CLAUDE.md` (main) | Feel requirements are marked in the request set. A play session is a pause for the owner; their notes go to `problem-solver`. |
| planner | Feel groups end with a play session. A scene file belongs to one item at a time; `project.godot` changes go one at a time. Trivial: tuning values in data files, text, scene layout without scripts. |
| foundation-worker, standard-worker | Logic stays out of the view. Tests only for obscure logic, each with `catches:`; replays before unit tests. Candidate tests are untagged. Tunable values live in data, not code. |
| inspector | Reads for logic in the view, string node paths, autoload abuse, missing static types, physics outside the physics step; LLM habits: re-introduced variables, comments repeating code, functions without levels of abstraction; test tampering. |
| reviewer | Runs the minimal check and the tagged tests of touched areas; explains failures with the failure history; assigns tags; checks test tampering. |
| problem-solver | A defect leaves a regression replay or test with `catches:` and `def:`. A feel note is tuned in data first. |
| tester | Tries the group with replays and probes from the project's scenario tools; may judge the view from low-resolution screenshots. |
