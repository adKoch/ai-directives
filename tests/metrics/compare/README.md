# The comparison of setups and its tests

The comparison is `scripts/compare-setups.sh` with its parts in `scripts/compare/`. What it reads, shows and
refuses: `docs/compare-setups.md`. This page says how it is built, how it is tested and how to extend it.

## Reading order
1. `docs/compare-setups.md`, then `docs/metrics-format.md`, "The roll-ups": what a roll-up holds.
2. `scripts/compare-setups.sh`, top to bottom: `main` is the whole flow (help, the folders, the roll-ups found,
   the comparison, the print).
3. `scripts/compare/projects.sh`: the port. Every place is checked before any file is read; `rollup_facts` prints
   the facts; `shown` is the one way a place from outside is printed.
4. `scripts/compare/reading.jq`, from the bottom (`read_rollup`) up: a roll-up's text in, its numbers out, taken
   only when the collector's `rollup_text` writes the same bytes from them.
5. `scripts/compare/comparison.jq`, from the bottom (`comparison`) up: facts in, setups and plans out.
6. `scripts/compare/figures.jq`: the figures shown, one line each. `scripts/compare/comparison_text.jq`: the text.
7. `scripts/compare/program.sh`: how the collector's modules and these are joined.
8. `comparing.sh`, then `side-by-side.test.sh`, `refusals.test.sh` and `output.test.sh`: how a test is written.

## The pattern
| Layer | Files | Does |
|---|---|---|
| Entry | `scripts/compare-setups.sh` | reads the arguments, checks the tools, takes the budget, wires the port to the rules, prints; decides nothing |
| Port (bash, read-only) | `scripts/compare/projects.sh` | every effect: finds and checks the places, reads each roll-up whole into a JSON fact, escapes each place it may print |
| Rules (jq, pure) | `reading.jq`, `comparison.jq`, `figures.jq`, `comparison_text.jq`, with the collector's `format.jq`, `rollup.jq`, `rollup_text.jq` | every decision; the roll-up format is the collector's, never written twice |
| The seam | `program.sh`: `comparison_jq "<collector/... compare/...>" '<filter>' <jq options>` | joins the named modules of both folders into one program, in the order given |

The flow: `find_rollups` checks every project folder and every `.md` file of its `ctxm/metrics/` and keeps the
list; `rollup_facts` prints `{kind: "project", project, shown}` and `{kind: "rollup", project, file, shown, text}`;
`comparison` takes them all (`--slurp`) and gives `{text}` or `{refusal}`. `read_rollup` reads each text back into
the object `rollup_of` makes; `setups` groups the roll-ups by project and fingerprints; `columns` makes a column
of each setup and plan, whatever the plans are named (in `plan_order`: `v0.9` before `v0.10`); `item_names`
lists every task name of every column once, matched by name, `none` in a column without it.

## The test helpers (`comparing.sh`)
| Helper | Does |
|---|---|
| `rolled_up_project <folder> <history> [<start>]` | builds `<folder>/project` with the plan `REQ-900` and the runs of `reviewed-items` (`../rollup/`), started at the time, and collects it with the real collector: its roll-up is what a project holds |
| `rolled_up_project_with_plans <folder> <history> <start> <plan> <text>...` | the same with the plans given (a name and a text each) instead of `REQ-900`: a roll-up for each plan whose items ran; `''` as the start for the default |
| `compare <arguments>`, `compared <arguments>` | run the command as a person does, in an empty environment with a UTF-8 locale and a `TMPDIR` in the test folder; `./stdout`, `./stderr`, `./status`, `./files-before`, `./checkout-before`; `compared` fails unless the status is 0. `COMPARISON_PATH` narrows its `PATH` |
| `compare_into_a_closed_pipe <arguments>` | the same, with stdout a pipe nobody reads |
| `compare_into_a_full_device <arguments>` | the same, with stdout `/dev/full` |
| `figure_row <heading> <figure>` | the row of a figure in a section (`Plans`, `Item <task>`, `Setups`) of what was printed |
| `assert_nothing_written` | fails unless the test folder with its `TMPDIR`, and the library checkout (but `.git`, `.cache/tests`, `.cache/check`), are as they were before the last comparison: every file's size, inode and times |

A scenario's numbers differ between projects by when their metrics start: a later start leaves the runs that
ended before it out (`side-by-side.test.sh` names the times). A history of `../collector/histories/` or of the
fixtures gives another fingerprint (`templates-in-other-order`, `template-update`). A new test file is named in
`scripts/lib/test-files.sh`.

## Adding a figure
Worked example: `items at the round limit` (a plan figure made from the items' rounds).
1. The roll-up must hold it: a figure the collector does not write has no source (the stop rule of
   `docs/metrics-format.md`). A new roll-up figure is the collector's ("Adding a roll-up figure",
   `../collector/README.md`).
2. `reading.jq`: read it into the object, under the key `rollup_of` gives it, in `parsed` (a table's cells with
   `rows`, a bullet with `bullet`, a count with `count` or `count_or_unknown`). Until it is read, `rollup_text`
   writes the roll-up back without it and every roll-up is refused: `side-by-side.test.sh` fails on the collector's
   own output, which is the guard that the two stay in step. A figure the collector writes as a fixed word
   (`unknown`) is not read but shown as that word: the write-back check holds every roll-up to it, and the day
   it gets a source the same guard asks for its read.
3. `figures.jq`: one line, `["<the figure's words>", <its value>]`, in `plan_figures` or `item_figures`. A value
   that is no count is computed from the object, as `items at the round limit` from `.items[].rounds`.
4. `docs/compare-setups.md`, "What it shows", and a test only if the figure is made here (not copied): beside
   `test_two_projects_with_different_fingerprints_are_shown_side_by_side_per_item`, with `figure_row`.

## Adding a refusal or an abuse case
A place on disk is checked in `projects.sh`, before anything is read, with `refuse_place`, which prints the place
through `shown`. A text is checked in the rules (`comparison.jq`, `refuse_file`). Add its line to "Refusals" of
`docs/compare-setups.md` and a test in `refusals.test.sh` that sends the case and expects the line, nothing on stdout
and `assert_nothing_written`.

## What must not change
- Nothing is written, anywhere: no file, no cache, no temporary file. Facts travel through pipes and arguments.
- A roll-up is taken only when `rollup_text` writes it back byte for byte. Never loosen this into reading cells one
  by one: it is what keeps every text but numbers, times, checked names and fixed words out of the output.
- The roll-up format is the collector's modules, joined in; the comparison never copies a pattern, a header or a
  layout of them.
- Every place from outside is printed through `shown` (bash's `%q` in the C locale); every value of a roll-up
  through `field_text`.
- Every place is checked (kind, link, size) before the first file is read; the tools before anything.
- The command ends with 0 or 1; a closed stdout ends it quietly with 0.
- jq modules are joined by `comparison_jq`, never included in each other (jq 1.8.2 stops on a module that includes
  a module).
