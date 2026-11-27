# What a file of layout.jq holds, as Claude Code writes it: the records of a transcript and a run's `.meta.json`,
# filled with synthetic values. Of the makers, only this file writes the key names a real transcript uses (the
# tests of the support name the ones they read, so a renamed key changes them too); README.md says where each is
# known from. Every free text carries the mark, so one search of a collector's output shows whether text got out.
# jq reads a definition before its use, so the entry, file_content, is the last one: read from the bottom up.

def text_mark: "synthetic-text";

# The records some top-level sessions open with: the session's title and its agent name. They carry no uuid and no
# time.
def opening_records:
  (select(.title != null) | {type: "custom-title", customTitle: .title, sessionId: .id}),
  (select(.agent_name != null) | {type: "agent-name", agentName: .agent_name, sessionId: .id});

def prompt_record: {type: "user", message: {role: "user", content: .prompt}};

# The text of a call's records: free text, and when the shape gives `report_end`, that as the last line (a report ends
# with it).
def reply_text: if has("report_end") then "\(text_mark) report\n\(.report_end)" else "\(text_mark) reply" end;

# The call by which a run hands its report back, when the shape gives `handback_end`: the report is the call's
# `message`, ending with that line.
def handback_block: {
  type: "tool_use",
  id: "toolu_\(.call)",
  name: "SubagentHandback",
  input: {message: "\(text_mark) handed back\n\(.handback_end)"}
};

def reply_blocks: [{type: "text", text: reply_text}] + if has("handback_end") then [handback_block] else [] end;

def assistant_record($call; $model; $usage): {
  type: "assistant",
  requestId: "req_\($call.call)",
  message: {
    id: $call.call,
    type: "message",
    role: "assistant",
    model: $model,
    content: ($call | reply_blocks),
    usage: $usage
  }
};

def output_so_far:
  if has("earlier_records_output_tokens") then {output_tokens: .earlier_records_output_tokens} else {} end;

# The usage each record of a call carries: the last one the call's whole usage, the ones before it the same with
# the output counted so far, when the shape gives it.
def record_usages:
  (.usage + output_so_far) as $earlier
  | (range(1; .records // 1) | $earlier), .usage;

# One API call is written as several records under one message id.
def call_records($model):
  . as $call
  | record_usages
  | assistant_record($call; $model; .);

def compaction_record: {
  type: "system",
  subtype: "compact_boundary",
  content: "\(text_mark) compaction notice",
  compactMetadata: .compaction
};

# What one event of a shape writes. An event of an unknown kind stops the build.
def event_records($model):
  if has("prompt") then prompt_record
  elif has("call") then call_records($model)
  elif has("compaction") then compaction_record
  else error("unknown event: \(tojson)")
  end;

# What every record carries about the session, or the run of a session, that wrote it.
def writer_keys:
  {sessionId: .session, cwd: "/synthetic/project"}
  + (if .agent == null then {isSidechain: false} else {isSidechain: true, agentId: .agent} end);

# The uuid depends only on the writer's file and the record's place in it, so a copy of the record in another
# session's file has the same one, and so has every build of the shape. Twelve digits: four for the file, six for
# the event, two for the record; layout.jq (checked_shape) refuses a shape that would need more.
def synthetic_uuid($index):
  "00000000-0000-4000-8000-\("000000000000\(.writer.file * 100000000 + .position * 100 + $index)"[-12:])";

def timestamp($epoch): ($epoch | fromdateiso8601) + .minute * 60 | strftime("%Y-%m-%dT%H:%M:%S.000Z");

# The records of an event where layout.jq placed it.
def placed_records($epoch):
  . as $placed
  | [.event | event_records($placed.writer.model)]
  | to_entries[]
  | .key as $index
  | ($placed.writer | writer_keys)
    + ($placed | {uuid: synthetic_uuid($index), timestamp: timestamp($epoch)})
    + .value;

# A run's `.meta.json`. A run that has not finished has no `finished`.
def run_metadata:
  {agentType: .role, description, model}
  + (if .finished != null then {finished: true} else {} end);

def lines: map(tojson + "\n") | add;

# The content of one file of the layout, with minute 0 at $epoch.
def file_content($epoch):
  if has("run") then [.run | run_metadata] | lines
  else [(.session | opening_records), (.events[] | placed_records($epoch))] | lines
  end;
