# Test support for the metrics set

The helper tools the metrics tests and probes are built with. Nothing here reads a real transcript, and no value in
a fixture is copied from one: only key names and the file layout are mirrored.

| Tool | Expresses |
|---|---|
| `make-transcripts.sh <shape.json> <folder> <epoch> [<minute>]` | Claude Code's transcripts for one project, from a shape; with `<minute>`, as the files stand at that minute, so a second build with a later minute lets them grow |
| `make-project.sh <history.json> <folder> <epoch>` | a project with a git history whose commits hold the lock ctxm writes and the agent files |
| `testing.sh` | a test file: `test_` functions under a `# catches:` line, `assert_prints <expected> <command>` (never `assert_… "$(command)"`, which the lint refuses: it passes when the command fails but prints the expected value), `assert_equal`, `assert_same_content`, `assert_starts_with_content`, `fail`, an empty folder per test under `.cache/tests/` |
| `../fixtures/transcripts/*.json` | the shapes: one file per transcript shape, its `about` says what it holds and its token sums |
| `../fixtures/projects/*.json` | the histories: one file per project history |

`scripts/check.sh` runs every test file named in `scripts/lib/test-files.sh`; a new one is added there. The test step
fails when a named file is missing, when a `*.test.sh` under `scripts/` or `tests/` is not named, and when a file
ends before `run_tests` has run its tests; its summary line counts the files and the tests. A probe calls the two
makers by hand, with a folder in the task's workspace.

## Reading order
1. `../fixtures/transcripts/finished-run.json`: what a shape says.
2. `make-transcripts.sh`: the whole flow in one function: `layout.jq` decides the files, `records.jq` fills them,
   `files.sh` writes them.
3. `layout.jq`, from the bottom (`transcript_layout`) up: sessions, runs, copies, the minute.
4. `records.jq`, from the bottom (`file_content`) up: one definition per kind of record.
5. `make-project.sh` and `project.jq`: the same pattern for a git history.
6. `transcripts.test.sh`, `project.test.sh`, `../../../scripts/lib/tests/check.test.sh`: how a test is written;
   `testing.test.sh` and `../../../scripts/lib/tests/test-files.test.sh`: what the harness and the test step keep.

## A shape
| Key | Means |
|---|---|
| `sessions[].id`, `.model` | the session's id (its file is `<id>.jsonl`) and the model of its calls |
| `sessions[].title`, `.agent_name` | optional: the file opens with a title record, an agent-name record |
| `sessions[].copies` | optional, a session id: the session is resumed or forked from that one. Its file starts with what the other had written when this one's first event happens, and its folder holds the other's runs as they stood then |
| `sessions[].events[]`, `runs[].events[]` | in time order, each with its `minute` and one of the kinds below; at most 999999 per session or run |
| `{"prompt": <text>}` | one user record. A run's first prompt carries the task name |
| `{"call": <message id>, "usage": {…}, "records": <n>, "earlier_records_output_tokens": <n>}` | one API call, written as `records` assistant records (default 1, at most 100) under one message id. Each holds `usage`; with the last key, the records before the last hold that number as their output |
| `{"compaction": {"trigger": …, "preTokens": …}}` | one `compact_boundary` record |
| `sessions[].runs[]`: `agent`, `role`, `model`, `description`, `finished` | a subagent run: `subagents/agent-<agent>.jsonl` and `.meta.json`. `finished` is the minute the run finishes; without it the run never does |

At most 100 sessions, and 99 runs per session. The maker refuses a shape beyond these limits or with events out of
time order (`checked_shape` in `layout.jq`): the uuids would collide, and a later build would not only add.

Every time is `<epoch>` plus the minute. A history's commits have a `minute` too: give both makers the same epoch and
a commit stands at its minute of the session (`session-across-template-update.json` with
`projects/template-update.json`).

## Adding a transcript shape
- **The same kinds of record in a new arrangement** (most cases): add a shape file. Write its `about` with the token
  sums a reader needs, each API call once; every free text contains `synthetic-text`; ids are made up. A shape
  only one test folder needs may live in that folder: the makers take a path.
- **A new kind of record**: in `records.jq`, add a `<kind>_record` definition and its branch in `event_records`; add
  the event's row to the table above and its key names to the table below. Worked example: `compaction` (the
  definition `compaction_record`, its branch, its row above, the shape `compacted-session.json`).
- **A new file or a new relation between sessions**: in `layout.jq`; `copies` (`with_copied`) is the example.
- Save a test in `transcripts.test.sh` only for a property that a collector test would pass without, as the four
  there.

## What must not change
- Of the makers, only `records.jq` (transcripts) and `project.jq` (the lock, an agent file's front matter) write
  real key names; `layout.jq` knows none. The support's tests name the keys they read, so a renamed key changes them
  too.
- Every free text carries `synthetic-text`, and a key whose values are not free text is listed in `STRUCTURAL_KEYS`
  of `transcripts.test.sh`. So a collector test searches its output for the one mark. The mark test checks every
  built transcript shape; a project history carries the mark by hand (its agents' descriptions) and from
  `make-project.sh` (its commit messages), unchecked.
- A record's uuid comes from its writer's file and its position there. It is the same in every build and in every
  copy, and a build at a later minute only adds to an earlier one.
- The jq modules are pure and the makers write only through `write_files`; `make-project.sh` names its repository on
  every git call, so it can never commit to the repository around it.
- A jq module includes no other module: jq 1.8.2 stops with an assertion when a module included by a module calls
  one of its own definitions. `make-transcripts.sh` includes both and joins them.
- No value from a real transcript, ever; no real transcript is read to write a shape.

## Key names mirrored
None was read from a real transcript for this support. "Plan" means the findings of plan AD-REQ-009; "known" means
the maker's author knew the format without checking it here. The collector's read-only probe is the place to check
them, by key names only.

| Where | Keys | From |
|---|---|---|
| Layout | `<session>.jsonl`, `<session>/subagents/agent-<agent>.jsonl`, `agent-<agent>.meta.json` | plan |
| Every record | `type`, `uuid`, `timestamp` (with milliseconds), `sessionId`, `isSidechain`, `cwd`; in a run `agentId` | known |
| Prompt | `type: user`, `message.role`, `message.content` (a string) | known |
| API call | `type: assistant`, `requestId`, `message.id`, `.type`, `.role`, `.model`, `.content[].type`, `.content[].text`, `message.usage.input_tokens`, `.output_tokens`, `.cache_creation_input_tokens`, `.cache_read_input_tokens`; several records per `message.id` | plan (several records per id), known (names) |
| Compaction | `type: system`, `subtype: compact_boundary`, `content`, `compactMetadata.trigger`, `.preTokens` | plan (`compact_boundary`), known (the rest) |
| Session opening | `type: custom-title` with `customTitle`, `type: agent-name` with `agentName`, both with `sessionId`, neither with `uuid` or `timestamp` | plan (the two kinds), known (names) |
| `.meta.json` | `agentType`, `model`, `finished`, `description` | plan |
| Lock | `.ctxm/ctxm.lock`: `version = 6`, `[[templates]]` with `name`, `source`, `commit` | read from a project's lock |
| Agent file | front matter `name`, `description`, `model`, `effort` | read from a project's agent file |

Not checked, and written here as a choice: the value of `finished` (`true`; the plan says only that a running run
has none); that the records of a call before its last hold a smaller `output_tokens`; that a copied record keeps
the `sessionId` of the session that wrote it; that a copied run is as it stood at the fork.
