# Which files Claude Code keeps for the sessions of a shape, and which events each file holds:
#   <session>.jsonl
#   <session>/subagents/agent-<agent>.jsonl
#   <session>/subagents/agent-<agent>.meta.json
# Pure, and without a key name of a real record: records.jq turns a file's events into its records.
# jq reads a definition before its use, so the entry, transcript_layout, is the last one: read from the bottom up.

# The events with who wrote each and where it stands in the writer's file. A copy in another session's file keeps
# both, so it becomes the same record there.
def placed($writer): [to_entries[] | {minute: .value.minute, event: .value, position: .key, writer: $writer}];

def own_run($session; $file):
  . as $run
  | {agent, role, description, model, finished}
  + {events: (.events | placed({session: $session, agent: $run.agent, model: $run.model, file: $file}))};

# What a session writes by itself. Its files are numbered, the session's own first, then one per run.
def own_session($ordinal):
  . as $session
  | ($ordinal * 100) as $file
  | {id, copies, title, agent_name}
  + {
      events: (.events // [] | placed({session: $session.id, model: $session.model, file: $file})),
      runs: [.runs // [] | to_entries[] | .key as $run | .value | own_run($session.id; $file + $run + 1)]
    };

def written_by($minute): map(select(.minute <= $minute));

# The session as its files stand at that minute: a later event is not written yet, a run that has written nothing
# has no files, and a run that finishes later has not finished.
def standing_at($minute):
  .events |= written_by($minute)
  | .runs |= map(
      .events |= written_by($minute)
      | select(.events != [])
      | if .finished != null and .finished > $minute then .finished = null else . end
    );

def session_named($id): first(.[] | select(.id == $id)) // error("no session \($id) to copy");

# A resumed or forked session starts with what the earlier session had written when it began: the same events, and
# the same runs under its own folder. What the earlier session writes after that is not in the copy.
def with_copied($sessions):
  . as $session
  | if .copies == null then .
    else .events[0].minute as $began
      | ($sessions | session_named($session.copies) | with_copied($sessions) | standing_at($began)) as $earlier
      | .events = $earlier.events + .events
      | .runs = $earlier.runs + .runs
    end;

def run_files($session):
  "\($session)/subagents/agent-\(.agent)" as $path
  | {file: "\($path).jsonl", events},
    {file: "\($path).meta.json", run: {role, description, model, finished}};

def session_files:
  .id as $session
  | {file: "\(.id).jsonl", session: {id, title, agent_name}, events},
    (.runs[] | run_files($session));

def refuse($why): error("the shape \($why)");

def in_time_order: map(.minute) | . == sort;

def check_events($writer):
  (.events // []) as $events
  | if ($events | in_time_order | not) then refuse("lists the events of \($writer) out of time order")
    elif ($events | length) > 999999 then refuse("gives \($writer) more than 999999 events")
    elif any($events[]; (.records // 1) > 100) then refuse("writes a call of \($writer) in more than 100 records")
    else . end;

def check_session:
  check_events("session \(.id)")
  | if (.runs // [] | length) > 99 then refuse("gives session \(.id) more than 99 runs") else . end
  | (.runs // [] | map(check_events("run \(.agent)"))) as $_
  | .;

# A record's uuid is built from its writer's file and its place there (records.jq, synthetic_uuid), and a build at a
# later minute only adds to an earlier one when the events are in time order: a shape beyond these limits stops the
# build.
def checked_shape:
  if (.sessions | length) > 100 then refuse("has more than 100 sessions") else . end
  | (.sessions | map(check_session)) as $_
  | .;

# The files of the shape as they stand $minute minutes after its epoch: one entry per file, with the events of a
# transcript (and the session that opens it), or the run a `.meta.json` describes. A session that has written
# nothing by itself yet has no file, and neither have its runs.
def transcript_layout($minute):
  checked_shape
  | [.sessions | to_entries[] | .key as $ordinal | .value | own_session($ordinal)] as $sessions
  | [$sessions[] | standing_at($minute) | select(.events != [])] as $standing
  | $standing[]
  | with_copied($standing)
  | session_files;
