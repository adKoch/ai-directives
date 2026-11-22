# Which events there are and whose each is: every API call and every compaction of the project's transcripts
# once, however many files hold a copy of it.
# A resumed or forked session's file starts with a copy of the earlier session's records, and its folder holds a
# copy of the earlier runs: same ids, same times. So an event is known by its id, and belongs to one owner:
#   in a run's transcript           the run (its agent id)
#   in a session's own transcript   the session its records name
# Where the copies name several owners, the first of them in the order of their names owns it, in every collection.
# Pure. Read from the bottom (owned_events) up.

# The owner an event (the input) has by the transcript that holds it.
def owner_in($transcript):
  if $transcript.kind == "run" then "run/\($transcript.agent)" else "session/\(.session)" end;

def claimed_events: .[] as $transcript | $transcript.events[] | . + {owner: owner_in($transcript)};

def largest_usage: map(.usage) | {
  input: (map(.input) | max),
  output: (map(.output) | max),
  cache_read: (map(.cache_read) | max),
  cache_write: (map(.cache_write) | max)
};

# One event from its copies: the owner as above, the earliest time, and for a call the largest usage of each kind.
def one_event:
  . as $copies
  | .[0] + {owner: (map(.owner) | min), time: (map(.time) | min)}
  | if .kind == "call" then .usage = ($copies | largest_usage) else . end;

# The events of the transcripts (the input lists their facts), each once.
def owned_events: [claimed_events] | group_by(.id) | map(one_event);

# The events by their owner (`run/<agent id>`, `session/<session id>`).
def by_owner: group_by(.owner) | map({key: .[0].owner, value: .}) | from_entries;
