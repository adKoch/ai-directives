# Outline: coding

## Commands
Must cover: one script per step (build, lint, format, test, the minimal check, tests by tag, tagging a test, listing
dormant tests by age, the failure history, the helper tools for probes); what each takes, prints and how long it
may run; how it runs from a plain shell; where logs and scratch files go.
Assumed: every step is a script; none needs a person; none runs over 5 minutes by default.
Read by: all workers, reviewer, release-tester, problem-solver

## Checks and tiers
Must cover: the tiers, who runs each and when; the check groups, the paths each covers, selection by changed files,
per-group time budgets, how a group over budget is split; how the size limits are enforced.
Assumed: a worker runs only the minimal tier; no budget above 5 minutes.
Read by: workers, reviewer, release-tester, planner

## Code rules
Must cover: the language's conventions and lint setup; limits tightened from `.claude/rules/clean-code.md`; where
logic ends and effects begin (this project's ports and adapters); the smells the inspector reads for.
Assumed: logic is testable without effects; the rules file is the authority and the wiki points to it.
Read by: workers, inspector, problem-solver

## Domains and behaviours
Must cover: the domains (one per code folder) and the wiki and test folders that mirror them; the behaviours in the
glossary, each with its meaning, the domains it crosses, where it was defined and retired names; how a behaviour is
proposed (the doc map), approved (a request set), merged, split and retired.
Assumed: a domain exists only as a code folder; a behaviour only through an approved request set.
Read by: main, planner, librarian, reviewer, workers

## Helper tools and probes
Must cover: the helper tools (scenario runners, fixture builders, state dumps and diffs) and what each can express;
how a probe is written and run, and where its script and output go; how a probe becomes a saved test (a named break
that passes the gate, or a defect); how a missing tool is added.
Assumed: most checking is probes and none is saved; probe scripts live in the task workspace.
Read by: workers, reviewer, release-tester, problem-solver, planner

## Tests and tags
Must cover: the layers, their folders (`<layer>/<domain>/` or how the language places tests) and when each runs; the
three tags (`behaviour:`, `def:`, `rule:`) and where they live; the four-question gate; what dormant means; the
`catches:` line; how a candidate becomes tagged; re-tagging after a retirement; the dormant cleanup; what counts as
tampering.
Assumed: only the reviewer writes tags; untagged tests do not run; a benchmark reports and never fails.
Read by: workers, reviewer, release-tester, problem-solver

## Failure history
Must cover: what a run logs, how to query it by test, branch or domain, the classes `new`, `caught`, `edited`,
`flaky`, `regression on main`, and where counts are committed.
Assumed: the raw log stays local; counts are committed with the tags.
Read by: reviewer, problem-solver, planner

## Parallel work
Must cover: worktrees and per-worktree setup; files only one item may change at a time (manifests, locks, generated
files); how checks avoid colliding on shared resources.
Assumed: up to 3 workers at once; code scopes never overlap.
Read by: planner, workers
