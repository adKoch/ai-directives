# Outline: cli

## Commands and exit codes
Must cover: every command with its options, the exit-code table and where it is generated, the global options.
Assumed: a POSIX shell.
Read by: main, planner, workers, release-tester

## Output and machine-readable records
Must cover: the streams, colour rules, escaping, each record kind with its fields and fixed words, how a kind is added.
Assumed: none.
Read by: workers, inspector, reviewer

## Plans, dry runs and questions
Must cover: the plan format and identifier, the question and its answers, what makes a plan stale, which changes are
marked risky.
Assumed: none.
Read by: planner, workers, reviewer, release-tester

## Where things live
Must cover: config and data locations, the precedence of environment, config and defaults, any per-project folder.
Assumed: XDG-style directories.
Read by: workers, release-tester
