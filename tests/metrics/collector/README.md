# The collector and its tests

The collector is `ctxm/agents-base/.claude/scripts/collect-metrics.sh` with the parts in `metrics/` beside it; the
`agents-base` template ships both to a project. What it writes and by which rules: `docs/metrics-format.md`. This
page says how it is built, how it is tested and how to extend it.

## Reading order
1. `docs/metrics-format.md`: the files, the columns, "What becomes a line", "The record".
2. `collect-metrics.sh`, top to bottom: `main` is the whole flow (tools, project, store, then the first collection
   or a later one); `collect` shows how a plan becomes a write.
3. `metrics/format.jq`: the columns, the fixed words, the patterns, the one place a line is written.
4. `metrics/facts.jq`, from the bottom (`transcript_facts`) up: a transcript in, facts out.
5. `metrics/counted.jq`, then `metrics/events.jq`: the record of what the lines counted, by id, and how it is
   checked against `tasks.csv`; each call and compaction once, which of them the record holds, and whose the others
   are.
6. `metrics/lines.jq`, from the bottom (`plan`) up: facts in, lines out. `metrics/report.jq`: the words.
7. `metrics/setup.jq` and `metrics/project.sh`: a commit's lock and agent files become a fingerprint.
8. `metrics/rollup.jq` and `metrics/rollup_text.jq`, from the bottom up: lines, commits and plans become a roll-up
   and its text.
9. `metrics/plans.sh`, `metrics/rollup_facts.jq`, `metrics/transcripts.sh`, `metrics/store.sh`, `metrics/places.sh`,
   `metrics/leftovers.sh`, `metrics/tools.sh`, `metrics/program.sh`, `metrics/telling.sh`: the edges.
10. `collecting.sh`, then `runs.test.sh`: how a test is written; `copies.test.sh` for a case in both id orders;
    `../rollup/rolling.sh` and `figures.test.sh` for a roll-up.

## The pattern
| Layer | Files | Does |
|---|---|---|
| Entry | `collect-metrics.sh` | reads the options, checks the tools, wires the ports to the rules, prints; decides nothing |
| Ports (bash) | `project.sh` (git, read-only), `transcripts.sh` (the transcripts folder, read-only), `plans.sh` (the plans, the commits' subjects and the release candidates, read-only), `store.sh` (`ctxm/metrics/`, the only writer, `tasks.csv` and its record `counted.csv` included), `places.sh` (the checks of what stands in `ctxm/metrics/` before a read or a write), `tools.sh` (the tool requirement, and a tool run with its words escaped), `telling.sh` (what the collector prints) | every effect; each turns what it reads into JSON facts or text for the rules |
| Rules (jq, pure) | `format.jq`, `escaping.jq`, `facts.jq`, `setup.jq`, `counted.jq`, `events.jq`, `holdings.jq`, `lines.jq`, `report.jq`, `rollup.jq`, `rollup_text.jq`, `rollup_facts.jq` | every decision; they read their input and arguments and write nothing |
| The seam | `program.sh`: `metrics_jq "<modules>" '<filter>' <jq options>` | joins the named modules into one program, in the order given |

The flow of a collection: the ports print one JSON object per setup, session and run (the facts); `lines.jq`'s `plan`
takes them with the settings `{project, now, start, written, counted}` (the texts of `tasks.csv` and of its record,
empty when a file is not there) and gives `{added, content, counted, result, rollups, notes}` or `{refusal}`;
`counted` is the record afterwards, or null when the collection adds neither a line nor a row; `rollups` holds
`{plan, content}` for each plan that has lines, made from the lines `content` holds. The entry prints the notes and
the result, checks every roll-up's place, prepares the roll-ups, then the record and `content` with
`prepare_file`, and renames them together, in that order, with `publish_prepared`.

## The test helpers (`collecting.sh`)
| Helper | Does |
|---|---|
| `project <history>`, `started_project <history> [<start>]` | builds `./project` from a history (this folder's `histories/`, else the fixtures'); the second with `ctxm/metrics/start` as a first collection left it |
| `transcripts <shape> [<minute>]` | builds `./transcripts` from a shape (this folder's `shapes/`, else the fixtures'); `TRANSCRIPTS_EPOCH` moves its minute 0, `minutes_ago <n>` gives a time relative to now |
| `transcripts_in_id_order <given\|reversed> <shape> [<minute>]` | the same, with the session ids as the shape has them or in reversed order (`../support/shapes.jq`): a test that loops over both shows that no line depends on how the ids sort |
| `collect`, `collect_with <options>`, `run_collector <arguments>`, `collected` | run the collector as a program, in an empty environment but the `PATH` and a home of the test's own; `./stdout`, `./stderr`, `./status`; `collected` fails unless the status is 0 |
| `run_collector_into_a_closed_pipe <arguments>`, `in_collector_environment <command>` | the same with stdout a pipe nobody reads; the environment alone, for a command that names variables (`GIT_DIR`) or runs the collector some other way |
| `line_fields <agent or session id> <columns>` , `line_count` | read `tasks.csv` by column name |
| `assert_no_text_got_out` | fails when the mark of the shapes' free text stands in `ctxm/metrics/`, `./stdout` or `./stderr` |
| `written_files` | the project's files git does not know: everything the collector may have written |
| `metrics_files` | the names of the files in `ctxm/metrics/`, in byte order, so no locale changes the list |

The collector reads the clock, so a test never waits: it places the transcripts in time instead (the epoch long
past for a closed session, `minutes_ago 20` for an open one) and writes the start record it needs. A project built
in a test folder has its own repository; the collector refuses a folder that is not the top of one, so it never
reads the library's history.

Test files: `runs.test.sh` (run lines), `sessions.test.sh` (main's lines, copies), `copies.test.sh` (copies,
chains and deletions: each call once, in both id orders), `record.test.sh` (the record's refusals and its
write), `empty-files.test.sh` (an empty `tasks.csv` or record, refused only beside a full one), `start.test.sh`
(the start), `refusals.test.sh` (what stops a collection), `lock-formats.test.sh` (the lock formats read, and each pin refused), `lock-lines.test.sh` (each line of a lock the collector does not read, refused), `permissions.test.sh` (where it may not write or read), `text.test.sh` (no text gets out), `format.test.sh` (the page, the headers and an earlier header), `store.test.sh` (the collector's own working
files, its tools and its environment). The roll-up tests are in `../rollup/`: `figures.test.sh` (the
figures), `refusals.test.sh` (what a roll-up refuses or leaves out) and `writing.test.sh` (roll-ups and lines all
or nothing); `rolling.sh` adds plans and commits to a project and looks for its shapes and histories in its own
folder first (`SCENARIOS`). A new test file is named in `scripts/lib/test-files.sh`.

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
5. A project's `tasks.csv` from before the column has the shorter header. `written_lines` reads any header of the
   format that is a start of the columns, `first_format_width` columns at least (`header_width`), and
   `with_lines_added` moves the file to the current header (the rule to keep: an old line gets `unknown` in each
   column added since). `blocking` and `nits` were the first added; the test on a file under the old header is
   in `format.test.sh`. Never reorder, rename or drop a column: the roll-ups and the comparison read every
   project's file by these names.
6. Tests: the token and count tests of `runs.test.sh` and `sessions.test.sh` are the model; `format.test.sh`
   already compares the page with the header.

## Adding a lock format
The collector reads the locks of formats 6 (ctxm 0.7), 7 and 8 (ctxm 0.8) and refuses any other when a line needs that
setup. A lock before format 8 gives each template its commit; format 8 may add a template's released `version`
(`setup.jq`: `commit_template`, `version_template`). To read another format as well:
1. `setup.jq`: `applied_templates` decides by the lock's `version`; add the version to `commit_lock_formats`, or beside
   `version_lock_format` with a reader that gives the same list for the new format. Keep the refusal for every version
   that has no reader. `read_lock` reads only the lines ctxm writes and refuses any other (a header, a key or a form
   it does not know, a key twice, a multi-line string): a new key or table of the format is added there, never
   skipped.
2. A new part of the fingerprint inside `templates` (as the version) changes what two lines of one setup look like: it
   keeps the form of every line already written (a commit pin is still `<name>@<commit>`). A part that needs its own
   column is the note above ("Adding a metric").
3. `docs/metrics-format.md`: "Refusals", "What a value may look like" and the `templates` row. A new value gets its
   pattern in `format.jq` first (`is_template_version`, `is_pinned_commit`).
4. A history in `histories/` with the new lock (`tests/metrics/support/project.jq` writes the lock: a new key needs it
   extended; `header`, `extra_lines`, `top_lines` and `end_lines` write lines no ctxm would) and tests in
   `lock-formats.test.sh`: the fingerprint, a session across the update that moves the lock, and a refusal for each
   input the format reads; a refusal for each new line form in `lock-lines.test.sh`. The refusal of an
   unknown format, `test_a_lock_in_another_format_is_refused_naming_the_file` in `refusals.test.sh`, stays for the next
   unknown version (`histories/later-lock-format.json`): move that history's version up when a format is read.

## Adding a roll-up figure
1. `docs/metrics-format.md`, "The roll-ups": what it is made of, and that it is `unknown` while no line, commit or file
   gives it. A figure with no reliable source is `unknown` and goes back to main under the stop rule; never add a
   report line for it.
2. The number: from the lines in `rollup.jq` (`rollup_of` holds one key for each section), from git or `ctxm/` as a fact
   `plans.sh` prints and `rollup_facts.jq` reads, taken into the source in `lines.jq` (`collection`).
3. Its text: a row or a bullet in `rollup_text.jq`. Every value passes `field_text`; a value that is not a number, a
   fixed word or a checked name stops the collection.
4. A test in `../rollup/figures.test.sh` that compares the figure with the sum of the lines it names.
5. The comparison reads the roll-up too, and refuses a roll-up whose figures it does not know: change it as
   "Adding a figure" says (`../compare/README.md`).

## Adding a kind of event the record holds
The record (`counted.csv`) holds every event of a main session's line, by kind and id, so that whether it was
counted never rests on times. Worked example: `compaction`, the second kind after `call`.
1. `facts.jq`: the event under the key `<kind>/<id>` in `events` (`add_compaction` puts `compaction/<uuid>`), its id
   checked against a pattern of `format.jq` (`is_record_id`) that starts with a letter or a digit, so it is a field.
   A transcript whose id does not fit is counted as not read whole.
2. `counted.jq`: the kind in `is_event_of`, with its pattern; nothing else there names a kind.
3. `docs/metrics-format.md`: the kind in "The record" (the `kind` row), the id's shape in "What a value may look
   like".
4. `lines.jq` counts the kind per line (`counted`), as "Adding a metric" says; `events.jq` and the record take any
   event of the facts as they are.
5. Tests: a shape whose copies hold the kind and whose original is then deleted, as `copies.test.sh` does for calls
   and `sessions.test.sh` for a compaction (`forked-session`); a row of the kind with an id of another shape in
   `test_a_record_with_a_row_that_is_no_row_of_the_record_is_refused_and_left_byte_for_byte` (`record.test.sh`).

A run's events have no rows: a run is counted once by its agent id, and its transcript is not read again once it
has its line. Giving runs rows is a new rule for the format page first.

## Adding a refusal or an abuse case
A value read from outside gets a pattern in `format.jq` and is checked where it is read (`facts.jq`, `setup.jq`);
a place on disk is checked in its port. Decide which of the two answers it gets: left out and counted (one
transcript's problem: a note in `report.jq`), or the collection refused (the project's problem: `refuse` in the
rules, `refuse` in a port). Add its line to "Refusals" or "What a value may look like", and a test that sends the
case and expects the refusal and nothing written: `text.test.sh` for transcripts (a shape in `shapes/` whose
payload holds the mark), `refusals.test.sh` for the project.

## What must not change
- Only `store.sh` writes, only into `ctxm/metrics/`, and only through `prepare_file` and `publish_prepared` (prepare
  every file, keep each old one, then rename them; `restore_renamed_files` undoes a write that stopped, and an
  old file it could not put back is never removed: `refuse_unsettled_files` stops every later collection until a
  person settles it). No temporary file anywhere else: facts travel through pipes and arguments. A roll-up is
  written only for a plan file of `ctxm/plans/`; no other file of `ctxm/metrics/` is read or changed.
- Whether an event was counted is read from the record, never from the times of the lines. The record is written
  only with `tasks.csv`, renamed just before it, and only adds rows; a record or a `tasks.csv` it cannot read, or
  that is out of step with the other, is refused, never rebuilt from the transcripts. An uncounted event's owner is
  decided by times (`owner_of`), never by the order of the ids alone.
- Only `facts.jq` knows a transcript's key names, and nothing but numbers, ids and names that pass `format.jq`
  leaves it. A report's text stops at its last line: only the two counts of a `Findings:` line are kept. `setup.jq`
  is the same for the lock and the agent files.
- Every pattern is used through `matches`, which anchors at the true end of the value: `$` accepts a line break
  there.
- Every line is written by `csv_line` and every row of the record by `record_row`; no other code joins fields.
- A rule module has no effect and reads no clock: the entry passes `now` in.
- The tools are checked before anything is read; the collector ends with 0 or 1.
- jq modules are joined by `metrics_jq`, never included in each other (jq 1.8.2 stops on a module that includes a
  module).
- Lines are only added, columns only at the end, and the three fixed words keep their meaning.
