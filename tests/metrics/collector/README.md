# The collector and its tests

The collector is `ctxm/agents-base/.claude/scripts/collect-metrics.sh` with the parts in `metrics/` beside it; the
`agents-base` template ships both to a project. What it writes and by which rules: `docs/metrics-format.md`. This
page says how it is built, how it is tested and how to extend it.

## Reading order
1. `docs/metrics-format.md`: the files, the columns, "What becomes a line".
2. `collect-metrics.sh`, top to bottom: `main` is the whole flow (tools, project, store, then the first collection
   or a later one); `collect` shows how a plan becomes a write.
3. `metrics/format.jq`: the columns, the fixed words, the patterns, the one place a line is written.
4. `metrics/facts.jq`, from the bottom (`transcript_facts`) up: a transcript in, facts out.
5. `metrics/events.jq`: each call and compaction once, and whose it is.
6. `metrics/lines.jq`, from the bottom (`plan`) up: facts in, lines out. `metrics/report.jq`: the words.
7. `metrics/setup.jq` and `metrics/project.sh`: a commit's lock and agent files become a fingerprint.
8. `metrics/transcripts.sh`, `metrics/store.sh`, `metrics/tools.sh`, `metrics/program.sh`: the edges.
9. `collecting.sh`, then `runs.test.sh`: how a test is written.

## The pattern
| Layer | Files | Does |
|---|---|---|
| Entry | `collect-metrics.sh` | reads the options, checks the tools, wires the ports to the rules, prints; decides nothing |
| Ports (bash) | `project.sh` (git, read-only), `transcripts.sh` (the transcripts folder, read-only), `store.sh` (`ctxm/metrics/`, the only writer), `tools.sh` (the tool requirement) | every effect; each turns what it reads into JSON facts or text for the rules |
| Rules (jq, pure) | `format.jq`, `facts.jq`, `setup.jq`, `events.jq`, `lines.jq`, `report.jq` | every decision; they read their input and arguments and write nothing |
| The seam | `program.sh`: `metrics_jq "<modules>" '<filter>' <jq options>` | joins the named modules into one program, in the order given |

The flow of a collection: the ports print one JSON object per setup, session and run (the facts); `lines.jq`'s `plan`
takes them with the settings `{project, now, start, written}` and gives `{added, content, result, notes}` or
`{refusal}`; the entry prints the notes and the result and hands `content` to `store`.

## The test helpers (`collecting.sh`)
| Helper | Does |
|---|---|
| `project <history>`, `started_project <history> [<start>]` | builds `./project` from a history (this folder's `histories/`, else the fixtures'); the second with `ctxm/metrics/start` as a first collection left it |
| `transcripts <shape> [<minute>]` | builds `./transcripts` from a shape (this folder's `shapes/`, else the fixtures'); `TRANSCRIPTS_EPOCH` moves its minute 0, `minutes_ago <n>` gives a time relative to now |
| `collect`, `collect_with <options>`, `run_collector <arguments>`, `collected` | run the collector as a program, in an empty environment but the `PATH` and a home of the test's own; `./stdout`, `./stderr`, `./status`; `collected` fails unless the status is 0 |
| `line_fields <agent or session id> <columns>` , `line_count` | read `tasks.csv` by column name |
| `assert_no_text_got_out` | fails when the mark of the shapes' free text stands in `ctxm/metrics/`, `./stdout` or `./stderr` |
| `written_files` | the project's files git does not know: everything the collector may have written |

The collector reads the clock, so a test never waits: it places the transcripts in time instead (the epoch long
past for a closed session, `minutes_ago 20` for an open one) and writes the start record it needs. A project built
in a test folder has its own repository; the collector refuses a folder that is not the top of one, so it never
reads the library's history.

Test files: `runs.test.sh` (run lines), `sessions.test.sh` (main's lines, copies), `start.test.sh` (the start),
`refusals.test.sh` (what stops a collection), `text.test.sh` (no text gets out), `format.test.sh` (the page and
the header). A new test file is named in `scripts/lib/test-files.sh`.

## Adding a metric (a column)
Worked example: `compactions`.
1. `docs/metrics-format.md`: a row at the **end** of "Columns" (here it stands where it was first written; from now
   on only the end).
2. `format.jq`: the name at the end of `columns`. The header, the line writer and the reader follow from it.
3. Where the number comes from:
   - from a transcript: a key in `facts.jq` (`is_compaction`, `add_compaction` put an event of the kind
     `compaction` into the facts), counted per line in `lines.jq` (`counted`). A new key name also gets its row in
     "Key names read from a transcript", and the maker of synthetic transcripts must write it
     (`tests/metrics/support/README.md`, "A new kind of record").
   - from git or the project: a fact printed by `project.sh`, taken into the line in `lines.jq`.
4. A value with no source is `unknown`; a text value needs a pattern in `format.jq` and a row in "What a value may
   look like".
5. A project's `tasks.csv` from before the column has the shorter header, which `written_lines` refuses today: no
   column has been added yet. The item that adds the first one also moves such a file to the new header, in
   `written_lines` and `with_lines_added` (the rule to keep: an old line gets `unknown` in the new column), with a
   test on a file written under the old header. Never reorder, rename or drop a column: the roll-ups and the
   comparison read every project's file by these names.
6. Tests: the token and count tests of `runs.test.sh` and `sessions.test.sh` are the model; `format.test.sh`
   already compares the page with the header.

## Adding a lock format
The collector reads the lock ctxm 0.7 writes (`version = 6`) and refuses any other when a line needs that setup.
To read another format as well:
1. `setup.jq`: `applied_templates` decides by `.version`; add the version beside `lock_version` and a reader that
   gives the same list, `<name>@<library commit>` per template, for the new format. Keep the refusal for every
   version that has no reader. `read_lock` is the reader of version 6: a second format gets its own.
2. If the fingerprint gains a part (a template's version), it is a new column: the note above.
3. `docs/metrics-format.md`: "Refusals" and the `templates` row.
4. A history in `histories/` with the new lock (`tests/metrics/support/project.jq` writes the lock: a new format
   needs it extended) and a test beside `test_a_lock_in_another_format_is_refused_naming_the_file`, which stays for
   the next unknown version (`histories/later-lock-format.json`).

## Adding a refusal or an abuse case
A value read from outside gets a pattern in `format.jq` and is checked where it is read (`facts.jq`, `setup.jq`);
a place on disk is checked in its port. Decide which of the two answers it gets: left out and counted (one
transcript's problem: a note in `report.jq`), or the collection refused (the project's problem: `refuse` in the
rules, `refuse` in a port). Add its line to "Refusals" or "What a value may look like", and a test that sends the
case and expects the refusal and nothing written: `text.test.sh` for transcripts (a shape in `shapes/` whose
payload holds the mark), `refusals.test.sh` for the project.

## What must not change
- Only `store.sh` writes, only into `ctxm/metrics/`, and only through `store` (prepare, then rename). No temporary
  file anywhere else: facts travel through pipes and arguments.
- Only `facts.jq` knows a transcript's key names, and nothing but numbers, ids and names that pass `format.jq`
  leaves it. `setup.jq` is the same for the lock and the agent files.
- Every pattern is used through `matches`, which anchors at the true end of the value: `$` accepts a line break
  there.
- Every line is written by `csv_line`; no other code joins fields.
- A rule module has no effect and reads no clock: the entry passes `now` in.
- The tools are checked before anything is read; the collector ends with 0 or 1.
- jq modules are joined by `metrics_jq`, never included in each other (jq 1.8.2 stops on a module that includes a
  module).
- Lines are only added, columns only at the end, and the three fixed words keep their meaning.
