# REQ-001 roles

Roles name a tier, never a model. Tiers are template variables:
`model_foundation` (Fable, with `effort_foundation`), `model_standard` (Sonnet), `model_strong` (Opus).
Domain layers add what each role does in their domain (code and tests in `coding`, renders and gates in `game-art`).

| Role | Tier | Runs | Writes | Gets | Returns |
|---|---|---|---|---|---|
| main | the session | nothing for the work | main's library, request sets | the owner | dispatches per plan; reports to the owner |
| planner | strong | read-only commands | the plan | an approved request set, wiki, past failures and defects | the plan (`flow.md`) |
| foundation-worker | foundation | the project's checks | work in its scope, a reading guide, an extension note, one worked example | a plan item | submission |
| standard-worker | standard | the project's checks | work in its scope | a plan item, the extension note it follows | submission |
| inspector | foundation | **nothing**: no commands, logs or output | nothing; returns a report | the plan item, the changed files and what they touch | findings, and a caselist when the plan asks |
| reviewer | standard | the checks, those of touched areas, the probes the worker named, at most one own probe | nothing; returns a report | the plan item, the commit, the submission | PASS, or findings; or a stop to main |
| problem-solver | strong | anything a worker may | work in its scope | findings, a failure, an exception, or an out-of-plan request | fix submission |
| tester | standard | tries against the group's requirements | only a check for a defect it found | the group's requirements, the commit, the caselist if any | pass, or defects |

The inspector's and reviewer's limits are their tool lists, which Claude Code enforces.

## Rules per role
- **main** keeps the owner's words in its library with dates; writes request sets; never plans or does the work.
  Runs the plan as written; sends exceptions to the owner, or back to the planner to replan.
- **planner** follows the planner guide. The plan is not approved by the owner; it is saved where the owner can read it.
- **foundation-worker** sets a pattern others follow; its extension note says how to add the next case.
- **standard-worker** follows an existing pattern; a needed new pattern is an exception, not a decision.
- **inspector** reads for problems visible without running, work the owner would struggle to understand, pattern
  breaks and weakened checks. The caselist names situations worth trying.
- **reviewer** judges technical soundness. On requirements it flags only what was obviously skipped.
  It **stops and returns to main** when a case means a requirement cannot be met as written.
- **problem-solver** takes every finding, every unexplained failure, defect, exception and out-of-plan work.
- **tester** tries the group; every run is documented, and only a found defect leaves a committed check.

## Main's section in CLAUDE.md
Every template that uses these roles adds to main's section which roles exist and when main calls each.
