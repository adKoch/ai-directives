# What one transcript says, as facts: the only file that knows the key names Claude Code writes
# (docs/metrics-format.md of the template library lists them and where each is known from).
# A transcript is read line by line and gives one object:
#   unreadable  how many of its lines could not be read as a record that counts
#   first, last the times of its first and last record, in seconds
#   sessions    the last time each session named by its records wrote one
#   events      its API calls and compactions, each once, by id
#   task        the task name of its first prompt, or null
# No text leaves this file: a value is a number, an id or a name that format.jq accepts, or null.
# Pure; needs format.jq. Read from the bottom (transcript_facts) up.

def field($key): if type == "object" then .[$key] else null end;

def is_timestamp: matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,9})?Z");
def seconds: sub("\\.[0-9]+Z$"; "Z") | (try fromdateiso8601 catch null);
def is_count: type == "number" and . >= 0 and . == floor;
def is_call_id: matches("[A-Za-z0-9_-]{1,128}");
def is_record_id: matches("[0-9a-f-]{1,64}");

# A prompt is a string, or a list of blocks whose text blocks hold it.
def prompt_text:
  if type == "string" then .
  elif type == "array" then map(select(field("type") == "text") | field("text") | strings) | join("\n")
  else ""
  end;

# The task name main gave the run: what stands in backticks after the first `Task:` of the prompt, when it is a
# task name. Anything else there gives null, and nothing of it is kept.
def named_task:
  (prompt_text | [match("Task: `([^`\\n]{1,200})`").captures[0].string] | first) as $name
  | if ($name | is_task_name) then $name else null end;

def usage_of($usage): {
  input: ($usage | field("input_tokens")),
  output: ($usage | field("output_tokens")),
  cache_read: ($usage | field("cache_read_input_tokens")),
  cache_write: ($usage | field("cache_creation_input_tokens"))
};

# An API call as one of its records tells it. A model that is no model name becomes null: the line it belongs to
# is then not written (lines.jq).
def call_of($record):
  ($record.message | field("model")) as $model
  | {
      kind: "call",
      id: ($record.message | field("id")),
      model: (if ($model | is_model) then $model else null end),
      usage: usage_of($record.message | field("usage"))
    };

def is_readable_call: (.id | is_call_id) and all(.usage[]; is_count);

# The records of one call repeat its usage; where they differ, the call's is the largest of each kind (an output
# still being written grows).
def merged_with($call):
  if . == null then $call
  else .time = ([.time, $call.time] | min)
    | .usage |= with_entries(.value = ([.value, $call.usage[.key]] | max))
  end;

def add_call($record; $time):
  call_of($record) as $call
  | if ($call | is_readable_call)
    then .events["call/\($call.id)"] |= merged_with($call + {time: $time, session: $record.sessionId})
    else .unreadable += 1
    end;

def add_compaction($record; $time):
  if ($record.uuid | is_record_id)
  then .events["compaction/\($record.uuid)"] = {kind: "compaction", time: $time, session: $record.sessionId}
  else .unreadable += 1
  end;

# Only a transcript's first prompt is looked at.
def add_prompt($record):
  if .prompted then . else .prompted = true | .task = ($record.message | field("content") | named_task) end;

def is_call: .type == "assistant" and (.message | field("model")) != "<synthetic>";
def is_compaction: .type == "system" and .subtype == "compact_boundary";
def is_prompt: .type == "user";
# Claude Code writes `<synthetic>` as the model of a message it made itself, without an API call: no call.
def counts: is_call or is_compaction or is_prompt;

def add_counted($record; $time):
  if ($record | is_call) then add_call($record; $time)
  elif ($record | is_compaction) then add_compaction($record; $time)
  elif ($record | is_prompt) then add_prompt($record)
  else .
  end;

def seen($session; $time):
  .first = ([.first, $time] | map(numbers) | min)
  | .last = ([.last, $time] | max)
  | .sessions[$session] = ([.sessions[$session], $time] | max);

def is_timed: (.timestamp | is_timestamp) and (.timestamp | seconds) != null and (.sessionId | is_session_id);

def add_timed($record; $time): seen($record.sessionId; $time) | add_counted($record; $time);

# A record that counts must be readable whole; any other kind (a session's title, its agent name, a request body)
# is used for its time at most, and its content is never looked at.
def add_record($record):
  if $record == null then .unreadable += 1
  elif ($record | is_timed) then add_timed($record; $record.timestamp | seconds)
  elif ($record | counts) then .unreadable += 1
  else .
  end;

# A line over the limit, or one that is no JSON object, is no record: null.
def record_of:
  if utf8bytelength > line_limit_bytes then null
  else (try fromjson catch null) | if type == "object" then . else null end
  end;

def no_facts: {unreadable: 0, first: null, last: null, sessions: {}, events: {}, prompted: false, task: null};

# The facts of the transcript whose lines are the inputs.
def transcript_facts:
  reduce (inputs | record_of) as $record (no_facts; add_record($record))
  | del(.prompted)
  | .events |= [to_entries[] | .value + {id: .key}];

# Adds what a run's `.meta.json` says ($text is empty when the run has none): whether the run has finished, and its
# role when that is a plain word. A file that is no JSON object makes the run unreadable.
def with_run_state($text):
  ($text | try fromjson catch null) as $meta
  | if $text == "" then . + {finished: false, role: null}
    elif ($meta | type) != "object" then . + {finished: false, role: null} | .unreadable += 1
    else . + {finished: ($meta.finished == true), role: ($meta.agentType | if is_role then . else null end)}
    end;
