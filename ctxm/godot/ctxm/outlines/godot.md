# Outline: godot

## Core and view
Must cover: the rules core (what it holds, what it never touches), the adapters around it, the fixed step, seeding,
commands and the state digest; where hot loops are and their data layout.
Assumed: the core runs without the scene tree.
Read by: planner, workers, inspector, reviewer, problem-solver

## GDScript conventions and traps
Must cover: typing and node references, signals and calls, autoloads, the physics step, the known traps, measured
costs.
Assumed: the project's gdlint and gdformat limits apply.
Read by: workers, inspector, reviewer, problem-solver

## GUT setup
Must cover: the test layers (unit, architecture scan, in-engine, benchmark) and their folders; fixtures; the post-run
hook; the architecture test guarding the core.
Assumed: tests are deterministic and headless.
Read by: workers, reviewer, release-tester, problem-solver

## Project files and worktrees
Must cover: the project file, scene files, `.uid` files, the import per worktree and clone, files one item may change
at a time, ignored folders.
Assumed: workers run in worktrees.
Read by: planner, workers, reviewer

## Headless runs and screenshots
Must cover: how to run the game, a replay, a probe and a screenshot; the timeout; GPU and software rendering.
Assumed: every run is headless except frame benchmarks.
Read by: release-tester, problem-solver, reviewer
