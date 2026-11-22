# Which lines a collection adds to tasks.csv: one per finished run, and one per setup for the new calls of each
# closed main session. The rules are in docs/metrics-format.md of the template library ("What becomes a line").
# The input of `plan` lists the facts: the project's setups (setup.jq, newest first) and one entry per transcript
# (facts.jq) with its `kind` ("run" with its `agent`, `finished` and `role`, or "session").
# Pure; needs format.jq, events.jq and report.jq. Read from the bottom (plan) up.

# The setup in force at a time, from the setups, newest first.
def setup_at($time): first(.[] | select(.since <= $time)) // {absent: true};

def calls: map(select(.kind == "call"));
def tokens($kind): calls | map(.usage[$kind]) | add // 0;
def models: calls | map(.model) | unique | if length == 0 then unknown else join("+") end;
def has_unplain_model: any(calls[]; .model == null);

# What a line counts, from its events (the input).
def counted: {
  input_tokens: tokens("input"),
  output_tokens: tokens("output"),
  cache_read_tokens: tokens("cache_read"),
  cache_write_tokens: tokens("cache_write"),
  compactions: (map(select(.kind == "compaction")) | length),
  model: models
};

def spanning($first; $last): {start: ($first | time_text), end: ($last | time_text), wall_seconds: ($last - $first)};

def fingerprint_of($setup): {project, templates: $setup.fingerprint.templates, roles: $setup.fingerprint.roles};

# What becomes of a run or a part of a session under its setup: a line, or the reason there is none.
def under($setup; line):
  if $setup.absent then {skipped: "no_setup"}
  elif $setup.problem then {refused: $setup.problem}
  else {line: line}
  end;

def run_line($run; $events; $setup):
  {task: $run.task, role: $run.role, session: $run.session, agent: $run.agent}
  + {effort: ($setup.fingerprint.efforts[$run.role] // unknown)}
  + spanning($run.first; $run.last)
  + ($events | counted)
  + fingerprint_of($setup);

# A run is written once, when it has finished, under the setup in force when it started.
def run_outcome($run):
  (.events["run/\($run.agent)"] // []) as $events
  | (.setups | setup_at($run.first)) as $setup
  | if $run.finished | not then {skipped: "unfinished"}
    elif $run.task == null then {skipped: "unnamed"}
    elif $run.role == null or ($events | has_unplain_model) then {skipped: "unplain"}
    elif $run.last <= .start then {skipped: "before_start"}
    else under($setup; run_line($run; $events; $setup))
    end;

# Of the copies of a run in several session folders, the one that went furthest tells its state.
def furthest_copy: sort_by([.finished, .last]) | last | . + {session: (.sessions | keys | first // unknown)};

def run_outcomes:
  . as $collection
  | .transcripts
  | map(select(.kind == "run" and ($collection.written_agents[.agent] | not)))
  | group_by(.agent)
  | map(furthest_copy as $run | $collection | run_outcome($run));

def session_line($session; $events; $setup):
  {task: nothing, role: main_role, session: $session, agent: nothing, effort: unknown}
  + spanning($events | map(.time) | min; $events | map(.time) | max)
  + ($events | counted)
  + fingerprint_of($setup);

# The part of a session's new events under one setup.
def part_outcome($session; $events):
  (.setups | setup_at($events[0].time)) as $setup
  | if ($events | has_unplain_model) then {skipped: "unplain"}
    else under($setup; session_line($session; $events; $setup))
    end;

# A session is written when it is closed, and only if it ended after the start: then whole, one line per setup.
def session_outcomes($session; $events):
  . as $collection
  | if .last[$session] > .now - quiet_seconds then [{skipped: "open"}]
    elif .last[$session] <= .start then [{skipped: "before_start"}]
    else $events
      | group_by(.time as $time | $collection.setups | setup_at($time) | .commit)
      | map(. as $part | $collection | part_outcome($session; $part))
    end;

# The events of a session that its lines have not counted yet: the ones after the last event of its lines.
def new_events($session):
  . as $collection
  | .events["session/\($session)"]
  | map(select(.time > ($collection.counted_until[$session] // -infinite)));

def sessions_with_events: .events | keys | map(select(startswith("session/")) | ltrimstr("session/"));

def all_session_outcomes:
  . as $collection
  | sessions_with_events
  | map(. as $session | $collection | new_events($session) | select(length > 0) | [$session, .])
  | map(. as [$session, $events] | $collection | session_outcomes($session; $events)[]);

# The outcomes, unless one of them refuses the collection.
def unless_refused: (map(.refused // empty) | first) as $why | if $why == null then . else refuse($why) end;

def skipped_counts: reduce (.[] | .skipped // empty) as $reason ({}; .[$reason] += 1);

# The last time each session named by a session's own transcript wrote a record.
def last_records:
  reduce (.[] | select(.kind == "session") | .sessions | to_entries[]) as $seen ({};
    .[$seen.key] = ([.[$seen.key], $seen.value] | max));

# The end of the last line each main session has.
def counted_until:
  reduce (.[] | select(.role == main_role)) as $line ({};
    .[$line.session] = ([.[$line.session], ($line.end | time_seconds)] | max));

def written_agents: map(select(.role != main_role) | {key: .agent, value: true}) | from_entries;

# The start record: one past time. Anything else there is refused, never repaired from the transcripts.
def start_seconds($now):
  if is_time and time_seconds <= $now then time_seconds
  else refuse("ctxm/metrics/start does not hold one past time such as 2026-01-05T09:00:00Z; restore it from git")
  end;

# What the lines are decided from: the readable transcripts, their events, and what tasks.csv and the start say.
def collection($facts; $settings):
  ($settings.written | written_lines) as $written
  | ($facts | map(select(.kind != "setup" and .unreadable == 0))) as $transcripts
  | {
      project: $settings.project,
      now: $settings.now,
      start: ($settings.start | start_seconds($settings.now)),
      setups: ($facts | map(select(.kind == "setup"))),
      transcripts: $transcripts,
      events: ($transcripts | owned_events | by_owner),
      last: ($transcripts | last_records),
      counted_until: ($written | counted_until),
      written_agents: ($written | written_agents)
    };

def planned($facts; $settings):
  collection($facts; $settings)
  | (run_outcomes + all_session_outcomes | unless_refused) as $outcomes
  | ($outcomes | map(.line // empty) | sort_by([.end, .start, .session, .agent])) as $lines
  | ($facts | map(select(.kind != "setup" and .unreadable > 0)) | length) as $unreadable
  | {
      added: ($lines | length),
      content: ($settings.written | with_lines_added($lines)),
      result: ($lines | result),
      notes: ($outcomes | skipped_counts + {unreadable: $unreadable} | notes)
    };

# The plan of a collection, from the facts (the inputs) and the settings {project, now, start, written}: what
# tasks.csv holds afterwards, the result and the notes; or the refusal, when nothing may be written.
def plan($settings):
  [inputs] as $facts
  | try planned($facts; $settings)
    catch (if type == "object" and has("refusal") then . else error end);
