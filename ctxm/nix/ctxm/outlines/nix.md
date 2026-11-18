# Outline: nix

## Toolchain and flake
Must cover: what the flake pins (inputs, channel, matched versions), the tools in the dev shell and why, the variables
it sets, how to update and verify an update, the platforms.
Assumed: Nix with flakes is the only host requirement.
Read by: main, planner, foundation-worker, reviewer, problem-solver

## Scripts and the dev-shell entry
Must cover: every script and what it takes; how a script enters the dev shell; shared helpers; exit codes, including
the budget stop; log and cache folders.
Assumed: every script is idempotent and works from a plain shell and the dev shell.
Read by: all workers, reviewer, release-tester, problem-solver

## Setup and first run
Must cover: prerequisites, the first run and what it downloads, optional direnv, host traps (GPU, untracked files).
Assumed: a fresh clone needs no other step.
Read by: workers, release-tester, librarian, main

## Release artifacts
Must cover: how an artifact is built, its file set, how dependencies are fetched and hashed, how licence notices
travel with it.
Assumed: a build fetches nothing outside the locks.
Read by: planner, foundation-worker, reviewer, release-tester
