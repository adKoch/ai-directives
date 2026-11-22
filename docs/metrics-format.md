# The format of `ctxm/metrics/`

What the collector of the `agents-base` template (`.claude/scripts/collect-metrics.sh`) writes into a project, and
by which rules. The roll-ups and the comparison command read this format. How the collector is built and extended:
`tests/metrics/collector/README.md`.

## Files
| File | Holds | Written |
|---|---|---|
| `ctxm/metrics/start` | one line: the time the project's metrics start | once, by the project's first collection |
| `ctxm/metrics/tasks.csv` | the header, then one line per agent run and per part of a main session | by every later collection that finds something; lines are only added |

Nothing else is written, anywhere. A file is replaced whole by a rename, so an interrupted collection leaves what
was there. The files hold numbers, times, ids, the fixed words and names that fit the patterns below: no prompt,
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
| `roles` | each role's model and effort as the agent files name them, `<role>=<model>/<effort>`, joined by `+` |

The four kinds of tokens are never added together. `project`, `templates` and `roles` are the setup's
fingerprint: two lines with the same three were made by the same setup. Times are UTC, to the second, as
`2026-01-05T09:00:00Z`.

## Fixed words
| Word | Means |
|---|---|
| `none` | the line has no such thing: a main session has no task and no agent id; a lock may list no template |
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

A field of `tasks.csv` starts with a letter or a digit and holds only letters, digits and `. _ : @ = / + [ ] -`: it
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
  earlier runs: a copied call belongs to the session its records name (the first of them in the order of their ids
  when the copies name several), a copied run is one line by its agent id.
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

## Refusals
The collector exits 1 with one `error:` line and writes nothing when: a required tool is missing; the project
folder is not the top of the project's main checkout (a subfolder, a linked worktree) or its name is no plain
name; the transcripts folder is missing; `ctxm`, `ctxm/metrics`,
`start` or `tasks.csv` is a symbolic link, or not a folder or a plain file; the transcripts folder holds a
symbolic link on the way to a transcript; `start` holds anything but one past time; `tasks.csv` has another header
or a line that is none of the format; a line needs a setup whose lock is not in the format ctxm 0.7 writes
(`version = 6`) or whose lock or agent files name something that is no plain word. A transcript with a line that is
no JSON record, lacks what a record must carry, or is longer than 8 MiB is left out whole and counted on stderr; so
is a run whose file name holds no agent id or whose `.meta.json` is no JSON object.

## Tools
The templates ship no toolchain. The collector needs these from the project's own, on the `PATH`, and checks for
them before it reads anything: `bash` 4.4 or later, `jq`, `git`, and `mkdir`, `mv`, `rm` (coreutils). Tested with
bash 5.3.9, jq 1.8.2, git 2.54.0 and coreutils 9.11.

## Key names read from a transcript
Only `facts.jq` knows them. "Checked" means seen on real transcripts on 2026-11-22, by key names, value types and
counts only; no value was kept.

| Where | Keys | Known from |
|---|---|---|
| Layout | `<session id>.jsonl`, `<session id>/subagents/agent-<agent id>.jsonl`, `agent-<agent id>.meta.json` | checked (an agent id is 17 lower-case letters and digits) |
| Every record that counts | `type`, `timestamp` (UTC with milliseconds), `sessionId` | checked |
| API call | `type: assistant`, `message.id`, `message.model`, `message.usage.input_tokens`, `.output_tokens`, `.cache_read_input_tokens`, `.cache_creation_input_tokens` | checked: 1 to 9 records per call, all with the same usage |
| Compaction | `type: system`, `subtype: compact_boundary`, `uuid` | checked, in session files only |
| First prompt | the first `type: user` record, `message.content` (a string, or blocks with `text`) | checked: the first record of every run, a string |
| `.meta.json` | `agentType`, `finished` (`true`; absent while the run runs) | checked; 118 of 740 runs have no `.meta.json` and are never taken as finished |
| Copies | a copied record keeps its `uuid`, `timestamp` and `message.id`; its `sessionId` is the earlier session's in two of three real cases and the new session's in one; of 59 runs that stand in several session folders, 57 are the same bytes in each and 2 have a shorter copy | checked |

Not read: `custom-title`, `agent-name`, `api-request` and every other kind of record (used for their time at
most); `.meta.json`'s `description` and `model` (absent in most real files, an alias in some: a line's model comes
from its calls).
