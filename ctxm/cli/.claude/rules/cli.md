# Command-line tools
On top of `.claude/rules/clean-code.md`.

## Output
1. Exit codes are a small fixed table (for example 0 ok, 1 error, 2 a state the user must act on, 3 aborted by the
   user). One source builds `--help`'s exit-code text and the docs; a test compares them.
2. Results go to stdout; notes, questions and `error: …` lines go to stderr. Output through a pipe is plain.
3. Colour only on a terminal, `NO_COLOR` respected, never in machine-readable output.
4. A machine-readable mode gives stable, line-based records: the first field is the kind, every field escaped,
   classifying fields are fixed words. Existing kinds keep their fields; new needs add kinds, never reorder fields.
   Human and machine output come from one plan, so they cannot disagree.
5. Text from outside (file names, file content, paths) is printed escaped, in one function, once.
6. An error is one line: what failed, which thing, what to do. Never a debug form. A closed pipe ends the command
   quietly.

## Changing files
7. A command that changes files first shows its plan: per-file lines (path, change, risk marks) and a plan identifier.
8. `--dry-run` prints the plan and writes nothing. Skipping the question needs the identifier of the plan shown; if
   anything changed since, refuse and write nothing.
9. The question defaults to No; any other answer or end of input aborts.
10. A write is all or nothing; an interrupted command writes nothing. A command that only reads writes nothing, not
    even its own bookkeeping.

## Commands
11. Global options mean the same in every command.
12. `--help` per command says what it does, its options and its exit codes; long reference lives in a docs page it
    points to.
13. A command wires adapters to the core; no domain logic lives in a command file. One file per command.
14. Commands are tested through the built binary in a sandbox: empty environment, throwaway home, piped stdin. Try a
    closed pipe, empty stdin, a non-UTF-8 path, `NO_COLOR`, and a plan changed between the dry run and the write.
