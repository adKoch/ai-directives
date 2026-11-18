# Outline: game-code

## Levers
Must cover: the levers in the glossary, each with its meaning, the domains it crosses, where it was defined and
retired names; the `lever:` tag in place of `behaviour:`.
Assumed: a lever exists only through an approved request set.
Read by: main, planner, librarian, reviewer, workers

## Replays and probes
Must cover: how a scenario is recorded (seed, input), replayed and checked (state digest); how a probe is described
and run; when a probe becomes a committed replay (only when it found a defect).
Assumed: game logic runs headless and deterministically from a seed.
Read by: release-tester, problem-solver, reviewer

## Feel and tuning
Must cover: where tunable values live, per lever; how a play session is handed off and how the owner reports it; how
a note becomes a change.
Assumed: tuning a value needs no code change.
Read by: main, planner, problem-solver

## Art handover
Must cover: where assets arrive, naming, scale, import settings, placeholders until art exists.
Assumed: art comes from a separate pipeline.
Read by: workers, planner
