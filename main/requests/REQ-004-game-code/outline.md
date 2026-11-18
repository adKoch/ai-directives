# Outline: game-code (draft of `main/outlines/game-code.md`)

## Commands
Must cover: one command each for the minimal check, tests by tag, tagging a test, a replay, a probe, a screenshot,
running the game, the failure history; what each takes and how long it may run.
Assumed: every command runs headless and within 5 minutes.
Read by: all workers, reviewer, tester, problem-solver

## Tests and tags
Must cover: the tag list and where tags live, what dormant means, the `catches:` line, how a candidate becomes tagged,
the cleanup of tests untagged over two releases.
Assumed: only the reviewer writes tags; untagged tests do not run.
Read by: workers, reviewer, problem-solver

## Failure history
Must cover: what a run logs, how to query it, the classes `new`, `caught`, `edited`, `flaky`, `regression on main`.
Assumed: the raw log stays local; counts are committed with the tags.
Read by: reviewer, problem-solver, planner

## Replays and probes
Must cover: how a scenario is recorded (seed, input), replayed and checked (state digest); how a probe is described
and run; when a probe becomes a committed replay (only when it found a defect).
Assumed: game logic runs headless and deterministically from a seed.
Read by: tester, problem-solver, reviewer

## Code rules
Must cover: the split between logic and view, the project's GDScript conventions, the lint setup, the Godot smells
the inspector reads for.
Assumed: logic is testable without the scene tree.
Read by: workers, inspector, problem-solver

## Feel and tuning
Must cover: where tunable values live, how the owner reports a play session, how a note becomes a change.
Assumed: tuning a value needs no code change.
Read by: main, planner, problem-solver

## Parallel work
Must cover: worktrees and the Godot import per worktree, which files only one item may change at a time.
Assumed: up to 3 workers at once.
Read by: planner, workers

## Art handover
Must cover: where assets arrive, naming, scale, import settings, placeholders until art exists.
Assumed: art comes from a separate pipeline.
Read by: workers, planner
