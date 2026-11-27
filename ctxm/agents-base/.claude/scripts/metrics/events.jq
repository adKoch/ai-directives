# Which events there are and whose each is: every API call and every compaction of the project's transcripts
# once, however many files hold a copy of it.
# A resumed or forked session's file starts with a copy of the earlier session's records, and its folder holds a
# copy of the earlier runs: same ids, same times. So an event is known by its id, and each copy names a holder:
#   in a run's transcript           the run (its agent id)
#   in a session's own transcript   the session its records name
# A copy names the earlier session or the new one, so the holders alone do not say whose the event is: what the
# lines have counted and where the metrics start decide it (owner_of), the same in every collection.
# Pure; with_owned_events takes the collection of lines.jq. Read from the bottom (with_owned_events) up.

# The holder an event (the input) has by the transcript that holds it.
def holder_in($transcript):
  if $transcript.kind == "run" then "run/\($transcript.agent)" else "session/\(.session)" end;

def claimed_events: .[] as $transcript | $transcript.events[] | . + {holder: holder_in($transcript)};

def largest_usage: map(.usage) | {
  input: (map(.input) | max),
  output: (map(.output) | max),
  cache_read: (map(.cache_read) | max),
  cache_write: (map(.cache_write) | max)
};

# One event from its copies: its holders (in the order of their names), the earliest time, and for a call the
# largest usage of each kind.
def one_event:
  . as $copies
  | .[0] + {holders: (map(.holder) | unique), time: (map(.time) | min)}
  | del(.holder)
  | if .kind == "call" then .usage = ($copies | largest_usage) else . end;

# The events of the transcripts (the input lists their facts), each once.
def held_events: [claimed_events] | group_by(.id) | map(one_event);

# The events (the input, each with its `owner`) by their owner (`run/<agent id>`, `session/<session id>`).
def by_owner: group_by(.owner) | map({key: .[0].owner, value: .}) | from_entries;

# Whether a line of the session (in the collection, the input) counted what the session held at that time, or the
# session ended before the start, so that nothing it held is ever counted.
def has_settled($session; $time):
  any(.counted_spans[$session][]?; .from <= $time and $time <= .to) or (.last[$session] // infinite) <= .start;

# Whose an event is, of its holders: a run that holds it; else a session that has settled it; else the first by
# name. So a copy that names the new session never takes an event from the session that counted it, nor brings one
# back from before the start.
def owner_of($event):
  . as $collection
  | $event.holders
  | if .[0] | startswith("run/") then .[0]
    else first(.[] | select(ltrimstr("session/") as $session | $collection | has_settled($session; $event.time)))
      // .[0]
    end;

# The collection (the input) with the events of its transcripts, each with its owner, by owner.
def with_owned_events($transcripts):
  . as $collection
  | .events = ($transcripts | held_events | map(. as $event | .owner = ($collection | owner_of($event))) | by_owner);
