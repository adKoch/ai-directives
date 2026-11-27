# The format of `ctxm/metrics/`

What the collector of the `agents-base` template (`.claude/scripts/collect-metrics.sh`) writes into a project, and
by which rules: the lines of `tasks.csv` and the roll-ups of the plans. The comparison command reads this format. How
the collector is built and extended: `tests/metrics/collector/README.md`.

## Files
| File | Holds | Written |
|---|---|---|
| `ctxm/metrics/start` | one line: the time the project's metrics start | once, by the project's first collection |
| `ctxm/metrics/tasks.csv` | the header, then one line per agent run and per part of a main session | by every later collection that finds something; lines are only added |
| `ctxm/metrics/<plan>.md` | the roll-up of a plan of `ctxm/plans/<plan>.md`: its figures and the fingerprint | by every later collection, whole, for each plan that has lines ("The roll-ups") |

Nothing else is written, anywhere. A file is replaced whole by a rename, and a collection renames its files only after
it has prepared all of them, so an interrupted collection leaves what was there. A file of the folder that is none of
these (another setup's roll-up, written by its own importer) is never read, changed or removed; only the working
files a killed collector left (`<file>.new.<process id>`, the process gone) are removed, by the next collection. The files hold numbers, times, ids, the fixed words and names that fit the patterns below: no prompt,
file or report text.

## Columns
In this order; the header is the names joined by commas. A column is only ever added at the end.

| Column | Means |
|---|---|
| `task` | the run's task name; `none` on a main session's line |
| `role` | the run's role (its agent type); `main` on a main session's line |
| `session` | the session id: of the main session, or of the session a run belongs to |
| `agent` | the run's agent id; `none` on a main session's line |
| `start` | a run's first record; on a main session's line, the first event the line counts |
| `end` | a run's last record; on a main session's line, the last event the line counts |
| `wall_seconds` | `end` minus `start`, in seconds |
| `input_tokens` | input tokens of the line's API calls, summed |
| `output_tokens` | output tokens, summed |
| `cache_read_tokens` | cache-read tokens, summed |
| `cache_write_tokens` | cache-write tokens, summed |
| `compactions` | how many times the context was compacted |
| `model` | the model of the line's API calls; several are joined by `+`; `unknown` when the line has no call |
| `effort` | the effort the role's agent file names in the line's setup; `unknown` when it names none, and for `main` |
| `project` | the name of the project's main checkout folder |
| `templates` | the applied templates, each as `<name>@<library commit>`, joined by `+`; `none` when the lock lists none |
| `roles` | each role's model and effort as the agent files name them, `<role>=<model>/<effort>`, joined by `+`; an agent file is a file of `.claude/agents/` that opens with front matter (`---`) |
| `blocking` | the first count of the `Findings:` line a run's report ends with; `none` when it ends with none, or with one that is no line of the format, and on a main session's line; `unknown` on a line written before the column existed |
| `nits` | the second count of that line, under the same words |

The four kinds of tokens are never added together. `project`, `templates` and `roles` are the setup's
fingerprint: two lines with the same three were made by the same setup. `templates` keeps the order the lock lists
the templates in, which is the order they were applied in, and a later template wins over an earlier one: the same
templates in another order are another setup. (`roles` is sorted: the agent files have no order.) Times are UTC, to the second, as
`2026-01-05T09:00:00Z`.

## Fixed words
| Word | Means |
|---|---|
| `none` | the line has no such thing: a main session has no task and no agent id; a lock may list no template; a run has no Findings counts |
| `unknown` | the value has no source: it is never guessed |
| `main` | the role of a main session's line |

No task, role, model, effort, agent id or project may be one of these words.

## What a value may look like
A value read from outside the collector is checked before use; one that does not fit is never written.

| Value | Pattern | Otherwise |
|---|---|---|
| task name | a request id with up to two prefixes (`REQ-004`, `AD-REQ-009`) or a release version (`v0.8`), then 1 to 8 parts of 1 to 24 letters and digits, joined by `-`; 80 characters at most | the run is counted and not written |
| role, model | a plain word: letters, digits and `-` (a model also `.`, `_`, `:`, `[`, `]`) | the run or the part is counted and not written |
| model, effort in an agent file; template name, library commit in the lock | plain words; 40 or 64 hex digits for a commit | the collection is refused when a line needs that setup |
| session id, agent id, API call id, time | their id shapes | the transcript is counted as not read whole |
| Findings line | the last line of the run's last text, exactly `Findings: <n> blocking, <m> nits`, each count 1 to 9 digits | the run is written with `none` in both columns; a last line that opens with `Findings:` and is none of the format is counted on stderr, and nothing of it is kept |
| token count | a whole number from 0 to 2^53 − 1, in any form JSON writes it (`1E2`, `10.0`); written as digits | the transcript is counted as not read whole |

A number in `tasks.csv` is written as digits. Any other field starts with a letter or a digit and holds only letters, digits and `. _ : @ = / + [ ] -`: it
cannot hold a separator, a quote or a line break, nor start a spreadsheet formula.

## What becomes a line
- **A run** (a subagent's transcript) is one line, written by the first collection that finds it finished. It
  counts all the run's API calls. Its task name is what stands in backticks after the first `Task:` of its first
  prompt, as ``Task: `REQ-004-A1-stack-split` ``; a run whose first prompt names no task this way is counted and
  not written. Its setup is the one in force when it started.
- **A main session** (a top-level transcript) is written only when it is closed: none of its records is younger
  than 60 minutes, so the session that runs the collector is never written. A line counts only the session's own
  API calls, never its runs'. A collection that finds calls a session's lines have not counted adds a line for those
  calls only, and one line per setup when the setup changed between them: a session's lines add up to its transcript.
- **Each API call counts once**, by its message id, in all the project's transcripts. One call is written as
  several records that repeat its usage; where they differ, the largest of each kind is the call's. A resumed or
  forked session's file starts with a copy of the earlier session's records, and its folder holds copies of the
  earlier runs; a copied run is one line by its agent id. A copied call's records name the earlier session or the
  new one, so of the sessions they name, the call belongs to one whose line has counted it already (its time falls
  within that line), else to one that ended before the start (so it is never written), else to the first in the
  order of their ids.
- **The setup in force** at a time is the project's state at the newest commit of the checked out branch, not
  later than that time, that changed `.ctxm/ctxm.lock` or `.claude/agents/`. A run or a part of a session at a
  commit without `.ctxm/ctxm.lock` is counted on stderr and not written.
- **The start.** The first collection writes `ctxm/metrics/start` and no line. From then on a run is written only
  if its last record is later than the start, and a main session only if its last record is: such a session is
  counted whole, its calls from before the start included. With the start record missing, the next collection is a
  first one again: it starts the metrics at that moment and adds nothing older, whatever transcripts are on disk.
- A run that is not written (unfinished, without a valid task name, unreadable) is looked at again by every
  collection. A run that has its line is never read again. A part of a main session that is not written is
  passed over once a later part of that session has its line.

## The roll-ups
The collector rewrites `ctxm/metrics/<plan>.md` for each plan of `ctxm/plans/` that has lines, whole, from `tasks.csv`,
git and `ctxm/`; the same inputs give the same bytes. It never writes a roll-up of a file that is not a plan under
`ctxm/plans/`: another setup's (the old releases') stays as it is.

- **A plan** is a plain file `ctxm/plans/<plan>.md` (not a link, at most 4 MiB). Its name is letters and digits in parts
  joined by one `.`, `_` or `-` (64 characters at most, so no `..`, no `/`, no leading dot); a file with another name,
  a link or a folder is left out and counted on stderr. Its **items** are the task names between backticks in its text
  (nothing else of the text is read or kept); a plan that no line names has no roll-up.
- **Where the metrics start**: the roll-up gives the project's start, the time the plan file was first committed, and
  `coverage`: `partial` when the start falls after that commit (what ended before it is in no number), `whole`
  otherwise, `unknown` when the file was never committed.
- **Setups**: each fingerprint among the items' lines, with its number of lines.
- **Cost**: per item and in all, the lines' tokens by kind, wall seconds and compactions. **Main's cost**: the lines of
  main sessions that overlap the plan's period (from the plan file's first commit to the end of its last item line),
  each counted whole, because a line is a whole session; two plans running at once both count it. A plan with no
  commit of its file, or whose lines all end before it, has no period: main's cost is `unknown`.
- **Flow**: an item's **rounds** are its review rounds: the larger of its inspector runs and its reviewer runs
  (the template's rule is 3 rounds at most; an item at 3 is at the limit). Exceptions, replans, out-of-plan requests
  and proposals raised are `unknown`: no line, commit or file records them.
- **Review**: from the `blocking` and `nits` columns, by role, and by item and role with each round in turn (the
  reports ordered by time, joined by `+`), the release-tester's included.
- **Escapes**: defects found at tests are the release-tester's blocking counts over the plan's items; release
  candidates are the files `ctxm/releases/v<x.y.z>-rc.<n>.md` of a plan named `v<x.y>`, `unknown` for any other plan.
  Owner change requests at a candidate, regressions on main and check failures after a merge are `unknown`.
- **Owner effort**: questions brought to the owner and the time items waited are `unknown`.
- **Product**: per item, the commits whose subject starts with `<task name>: `, and the lines they added and deleted
  (a binary file counts none). The seconds of the minimal check on main and the tests added are `unknown`.

`unknown` is the stop rule: a figure with no reliable source in the lines, git and `ctxm/` is never guessed and never
solved by adding a report line. A roll-up holds only numbers, times, ids, names that fit the patterns above and
the fixed words of the collector: every value passes the field check of the lines, so no text of a plan reaches it.

## What is not counted
- **A compaction's own summary call.** Checked on real transcripts (2026-11-22, by key names and numbers only): of
  18 `compact_boundary` records in 14 session files, none is accompanied by a record that carries the usage of the
  call that wrote the summary; the boundary holds `preTokens`, `postTokens` and `durationMs`, and the summary
  follows as a `user` record without usage. So a line's tokens leave the summary calls out, and `compactions` says
  how many there were.
- **A run's compactions**, as far as known: none of 740 real run transcripts holds a `compact_boundary` record. If
  Claude Code marks a run's compaction otherwise, the collector does not see it.
- **Calls a run makes after its line was written** (a finished run that is continued).
- A record whose model is `<synthetic>`: Claude Code writes it for a message it made itself, without an API call.

## Known limit: a copy that outlives its original
Whether a call was counted is read from the transcripts that hold it and the times of the lines: `tasks.csv` keeps
no call ids. So when a fork's or a resume's copy names the new session and the earlier session's own transcript is
deleted (Claude Code removes old ones) before the new session has a line, the next collection counts the copied
calls again, under the new session; and a session that ended before the start, deleted the same way, is counted
through such a copy. A copy that keeps the earlier session's id, or a new session that has its line before the
deletion, is counted once.

## Refusals
The collector exits 1 with one `error:` line and writes nothing when, at the first collection as at any other:
a required tool is missing; the project folder is not the top of the project's main checkout (a subfolder, a
linked worktree) or its name is no plain name; the transcripts folder is missing or holds a symbolic link on the
way to a transcript; `ctxm/plans` or `ctxm/releases` is a symbolic link; `ctxm`, `ctxm/metrics`, `start` or
`tasks.csv` is a symbolic link, or not a folder or a plain file. A later collection also when: a roll-up's place
(`ctxm/metrics/<plan>.md`) is a symbolic link or no plain file; `start` holds anything but one past time;
`tasks.csv` has a header that is none of the format's (an earlier header of it, with fewer columns, is read, and the
file moved to the current header with `unknown` in the columns added since) or a line that is none of the format; a
line needs a setup whose lock is not in the format ctxm 0.7 writes
(`version = 6`) or whose lock or agent files name something that is no plain word. A transcript with a line that is
no JSON record, lacks what a record must carry, or is longer than 8 MiB is left out whole and counted on stderr; so
is a run whose file name holds no agent id or whose `.meta.json` is no JSON object, and a transcript that is no plain
file (a folder, a pipe). A step that fails without a refusal of its own (a full disk, a read-only folder) ends the
collector the same way: exit 1, one `error:` line, nothing half-written. A closed stdout loses only the result: the
collection is done, exit 0.

## Tools
The templates ship no toolchain. The collector needs these from the project's own, on the `PATH`, and checks for
them before it reads anything: `bash` 4.4 or later, `jq`, `git`, and `mkdir`, `mv`, `rm` (coreutils). Tested with
bash 5.3.9, jq 1.8.2, git 2.54.0 and coreutils 9.11. It reads the repository of the project folder only: it drops
every `GIT_` variable of its environment (a git hook sets several: `GIT_DIR`, `GIT_INDEX_FILE`, an object folder, a
namespace) and keeps none, so git's own settings of the user and the system are read as they are, and it turns off
`log.showSignature`.

## Key names read from a transcript
Only `facts.jq` knows them. "Checked" means seen on real transcripts on 2026-11-22, by key names, value types and
counts only; no value was kept.

| Where | Keys | Known from |
|---|---|---|
| Layout | `<session id>.jsonl`, `<session id>/subagents/agent-<agent id>.jsonl`, `agent-<agent id>.meta.json` | checked (an agent id is 17 lower-case letters and digits) |
| Every record that counts | `type`, `timestamp` (UTC with milliseconds), `sessionId` | checked |
| API call | `type: assistant`, `message.id`, `message.model`, `message.usage.input_tokens`, `.output_tokens`, `.cache_read_input_tokens`, `.cache_creation_input_tokens` | checked: 1 to 9 records per call, all with the same usage |
| Compaction | `type: system`, `subtype: compact_boundary`, `uuid` | checked, in session files only |
| Report | the last `type: assistant` record's `message.content`: a string, or blocks, of which the last with `type: text` and a `text` is the report; only its last line is looked at | the API's message format; not checked on real transcripts (none was read for this) |
| First prompt | the first `type: user` record, `message.content` (a string, or blocks with `text`) | checked: the first record of every run, a string |
| `.meta.json` | `agentType`, `finished` (`true`; absent while the run runs) | checked; 118 of 740 runs have no `.meta.json` and are never taken as finished |
| Copies | a copied record keeps its `uuid`, `timestamp` and `message.id`; its `sessionId` is the earlier session's in two of three real cases and the new session's in one; of 59 runs that stand in several session folders, 57 are the same bytes in each and 2 have a shorter copy | checked |

Not read: `custom-title`, `agent-name`, `api-request` and every other kind of record (used for their time at
most); `.meta.json`'s `description` and `model` (absent in most real files, an alias in some: a line's model comes
from its calls).
