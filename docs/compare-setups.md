# The comparison of setups (`scripts/compare-setups.sh`)

The template library's command that compares template setups: it reads the roll-ups the collector wrote into each
project's `ctxm/metrics/` (`docs/metrics-format.md`, "The roll-ups") and shows the setups side by side, a column
for each setup and plan, whatever the plans are named: for each plan its cost, the items at the round limit, the
escaped defects and the owner's questions; for each item, matched by task name, its cost and its rounds. It reads
nothing else and writes nothing, anywhere. How it is built and extended: `tests/metrics/compare/README.md`.

## Usage
What `--help` prints (`scripts/compare/help.txt`; a test compares the two):

```text
usage: compare-setups.sh [--help] [--] <project folder>...
Shows the setups of the projects given side by side, read from the roll-ups in each project's ctxm/metrics/: a
column for each setup and plan, whatever the plans are named; for each plan its cost, the items at the round limit,
the escaped defects and the owner's questions; for each item, matched by task name, its cost and its rounds. A
setup is a project with its templates and roles (the fingerprint). It reads only ctxm/metrics/*.md and writes
nothing.
  <project folder>  the folder of a project whose metrics the collector wrote; 1 to 8 of them
  --help            print this text
  --                every argument after it is a project folder
Exit codes:
  0  the comparison is printed on stdout (into a closed pipe: nothing, quietly)
  1  refused or failed: one error: line on stderr and nothing on stdout, but for a write to stdout that failed
     part-way, which leaves what was written; a missing tool, an argument that is no project folder, a place that is
     a symbolic link, a file in ctxm/metrics/ that is no roll-up the collector wrote, a roll-up too large or
     unreadable, a jq step or a write to stdout that failed
Needs bash, jq and coreutils (dirname, basename, wc, timeout, sleep) from the caller's toolchain; LIBRARY_BUDGET_SECONDS sets
its time budget (300 seconds). The rules: docs/compare-setups.md of the template library.
```

For example, from the library's checkout, with the tools of a project's dev shell:

```text
scripts/compare-setups.sh ../game-a ../game-b
```

## What it reads
Every `.md` file of `<project folder>/ctxm/metrics/`, each a roll-up `<plan>.md`. A file is taken only when the
collector of this checkout of the library writes it back byte for byte from the numbers read from it: the
comparison reads the roll-up's figures, gives them to the collector's own `rollup_text`, and compares. So nothing
but numbers, times, checked names and the collector's fixed words is ever taken from another project, and a roll-up
written by an earlier collector, in a layout that has changed since, is refused until the project is collected again
with the current templates. `tasks.csv`, `start` and every other file of the folder are not read.

## What it shows
- **Setups**: a setup is what made a roll-up: its project (as given, and as the collector named it) and its
  fingerprints, the `templates` and `roles` of the roll-up's lines (the order of the templates counts: the same
  templates in another order are another setup). Each setup is numbered and listed with its fingerprints. A roll-up
  made under several fingerprints (a `ctxm update` during the plan) is one setup with a row for each: its numbers
  cannot be told apart.
- **Plans**: one table with a column for each setup and plan (`setup 1, v0.9`), whatever the plans are named, so
  later releases of one project and the plans of different projects stand side by side. The columns follow the
  setups' numbers, and within a setup its plan names with their numbers read as numbers (`v0.9` before `v0.10`).
  Each column shows `coverage`, the number of items, the plan's cost (runs, the four kinds of tokens, never added
  together, wall seconds, compactions), the items at the round limit, the defects found at tests, the release
  candidates, the owner's change requests at a candidate and the questions brought to the owner. The escapes and the
  owner's questions stand by plan, not by item: a roll-up counts them for the whole plan.
- **Items**: a section per task name found in any column, each listed once, with the same columns: its rounds and
  its cost. Items are matched by their task name, so two projects that ran the same plan stand side by side item by
  item; an item that no other column has is shown in its own column, with `none` in the others. The sections stand in
  the order of the task names, their numbers read as numbers (`REQ-900-1A` before `REQ-900-10A`).
- `coverage` `partial`: the project's metrics start after the plan's first commit, so what ended before the start
  is in no number of that plan; the plan is shown, never read as whole.
- `none`: the column's plan has no line of that item. `unknown`: the roll-up has no source for the figure (the stop
  rule of `docs/metrics-format.md`).

A place a person gave (a project folder, a file of it) is printed escaped, as bash's `%q` writes it in the C locale:
a control character, an escape sequence, a character that turns text around and a byte that is no UTF-8 are written
as escapes.

## Refusals
It exits 1 with one `error:` line, prints nothing on stdout and writes nothing when:
a tool is missing; no project folder is given, an option is not `--help` or `--`, or more than 8 folders are given;
a folder given is no folder, has no `ctxm/metrics/` folder, or holds no `.md` file there; `ctxm` or `ctxm/metrics`
is a symbolic link; `ctxm/metrics/` could not be read, holds a file an interrupted collection kept
(`<file>.old.<process id>`), or more than 100 `.md` files; a `.md` file there is no plain file (a link, a folder, a
pipe), could not be read, is larger than 1 MiB, or the roll-ups given hold more than 16 MiB together (sizes taken
from the file system before anything is read); a `.md` file's name is no plan name (`docs/metrics-format.md`, "The
roll-ups") or its text is not what the collector writes (above). The line names the place, escaped.

It also exits 1 with one `error:` line when a jq step fails (jq's own words are not shown: they may quote what it
read), and when the text cannot be written to stdout for any reason but a closed pipe, which ends it quietly with 0 (a write
that fails part-way leaves what it wrote).

## Tools
The library ships no toolchain. The comparison needs `bash` (4.4 or later), `jq`, and `dirname`, `basename`, `wc`,
`timeout`, `sleep` (GNU coreutils) on the `PATH`, and checks for jq, wc, timeout, dirname, basename and sleep
before it reads anything. Tested with bash 5.3.9, jq 1.8.2 and coreutils 9.11, from context-manager's dev shell.

## Known limits
- A file is checked where it stands, then read: a file swapped for a link between the two is read through the link.
  What it reads is still shown only when it is a roll-up the collector writes.
- The comparison reads the roll-up layout of the library checkout it runs from: compare with the library's version
  the projects were collected with, or collect them again.
