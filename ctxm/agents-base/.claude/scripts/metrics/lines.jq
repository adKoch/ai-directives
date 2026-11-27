# Which lines a collection adds to tasks.csv: one per finished run, and one per setup for the new calls of each
# closed main session. The rules are in docs/metrics-format.md of the template library ("What becomes a line").
# The input of `plan` lists the facts: the project's setups (setup.jq, newest first) and one entry per transcript
# (facts.jq) with its `kind` ("run" with its `agent`, `finished` and `role`, or "session").
# Pure; needs format.jq, events.jq, report.jq, holdings.jq, rollup.jq and rollup_text.jq. Read from the bottom
# (plan) up.

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

# The two counts of a run's Findings line; a run without one (or with a malformed one) has the fixed word.
def findings_columns($findings):
  if ($findings | type) == "object" then $findings else {blocking: nothing, nits: nothing} end;

def run_line($run; $events; $setup):
  {task: $run.task, role: $run.role, session: $run.session, agent: $run.agent}
  + {effort: ($setup.fingerprint.efforts[$run.role] // unknown)}
  + findings_columns($run.findings)
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
    else under($setup; run_line($run; $events; $setup)) + {malformed: ($run.findings == "malformed")}
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
  + findings_columns(null)
  + spanning($events | map(.time) | min; $events | map(.time) | max)
  + ($events | counted)
  + fingerprint_of($setup);

# The part of a session's new events under one setup.
def part_outcome($session; $events):
  (.setups | setup_at($events[0].time)) as $setup
  | if ($events | has_unplain_model) then {skipped: "unplain"}
    else under($setup; session_line($session; $events; $setup))
    end;

# What tells setups apart: the fingerprint; a setup without one (no lock, a problem) by its commit.
def setup_key: if .fingerprint then .fingerprint else {commit} end;

# The events (the input) in parts of the same setup, in time order: a commit that leaves the fingerprint as it was
# (an agent file's description) starts no new part.
def in_setup_parts($setups):
  sort_by(.time)
  | reduce .[] as $event ([];
      ($setups | setup_at($event.time) | setup_key) as $key
      | if length > 0 and .[-1].key == $key then .[-1].events += [$event] else . + [{key: $key, events: [$event]}] end)
  | map(.events);

# A session is written when it is closed, and only if it ended after the start: then whole, one line per setup.
def session_outcomes($session; $events):
  . as $collection
  | if .last[$session] > .now - quiet_seconds then [{skipped: "open"}]
    elif .last[$session] <= .start then [{skipped: "before_start"}]
    else $events
      | in_setup_parts($collection.setups)
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

# Why an outcome is counted on stderr: the run or part was not written, or the run was written without its
# Findings line because that line is none of the format.
def reasons: (.skipped // empty), (select(.malformed and .line != null) | "malformed_findings");

def skipped_counts: reduce (.[] | reasons) as $reason ({}; .[$reason] += 1);

def is_transcript: .kind == "run" or .kind == "session";

def facts_of($kind): map(select(.kind == $kind));

# What the lines are decided from: the readable transcripts, their events, and what tasks.csv and the start say.
# The plans, commits and release candidates are for the roll-ups only.
def collection($facts; $settings):
  ($settings.written | written_lines) as $written
  | ($facts | map(select(is_transcript and .unreadable == 0))) as $transcripts
  | {
      project: $settings.project,
      now: $settings.now,
      start: ($settings.start | start_seconds($settings.now)),
      setups: ($facts | facts_of("setup")),
      transcripts: $transcripts,
      last: ($transcripts | last_records),
      counted_spans: ($written | counted_spans),
      counted_until: ($written | counted_until),
      written_agents: ($written | written_agents),
      plans: ($facts | facts_of("plan") | map(select(.name != null))),
      commits: ($facts | facts_of("commits")),
      candidates: ($facts | facts_of("candidate"))
    }
  | with_owned_events($transcripts);

# The roll-ups of the plans, from the lines tasks.csv holds afterwards (the input is the collection): one per plan
# that has lines, each with the plan's name and its text.
def rollups_after($content):
  {lines: ($content | written_lines), plans, commits, candidates, start, project}
  | rollups | map({plan, content: rollup_text});

def unreadable_counts($facts): {
  unreadable: ($facts | map(select(is_transcript and .unreadable > 0)) | length),
  left_out_plans: ($facts | map(select(.kind == "plan" and .name == null)) | length)
};

def planned($facts; $settings):
  collection($facts; $settings)
  | (run_outcomes + all_session_outcomes | unless_refused) as $outcomes
  | ($outcomes | map(.line // empty) | sort_by([.end, .start, .session, .agent])) as $lines
  | ($settings.written | with_lines_added($lines)) as $content
  | {
      added: ($lines | length),
      content: $content,
      result: ($lines | result),
      rollups: rollups_after($content),
      notes: ($outcomes | skipped_counts + unreadable_counts($facts) | notes)
    };

# The plan of a collection, from the facts (the inputs) and the settings {project, now, start, written}: what
# tasks.csv holds afterwards, the result, the roll-ups and the notes; or the refusal, when nothing may be written.
def plan($settings):
  [inputs] as $facts
  | try planned($facts; $settings)
    catch (if type == "object" and has("refusal") then . else error end);
