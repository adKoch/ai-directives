# The record of what the lines counted: ctxm/metrics/counted.csv, as docs/metrics-format.md of the template library
# defines it ("The record"). Each API call and each compaction of a main session that a collection has settled is
# one row: the number of the line of tasks.csv that counts it (the first line under the header is 1), or `none` when
# it is passed over for good; then the event's kind and its id. Rows are only added, together with the lines they
# name. Whether an event was counted is read from here, never from the times of the lines.
# Pure; needs format.jq. Used by lines.jq; events.jq reads the events it gives. Read from the bottom (counted_events,
# with_rows_added) up.

def record_columns: ["line", "kind", "id"];
def record_header: record_columns | join(",");
def record_file: "ctxm/metrics/counted.csv";

def refuse_record($why): refuse("\(record_file) \($why); restore it from git");

# Whether the id has the shape of its kind's ids: an API call's message id, a compaction's uuid.
def is_event_of($kind): if $kind == "call" then is_call_id elif $kind == "compaction" then is_record_id else false end;

def is_line_number: matches("[1-9][0-9]{0,15}");

# A row as {line, event}: the number of its line (null for `none`) and the event as events.jq names it,
# `<kind>/<id>`. Anything else on the row (a fourth field, a quote, a line break) refuses the record.
def row_of:
  split(",") as $fields
  | $fields as [$line, $kind, $id]
  | if ($fields | length) == 3 and ($line == nothing or ($line | is_line_number)) and ($id | is_event_of($kind))
    then {line: (if $line == nothing then null else $line | tonumber end), event: "\($kind)/\($id)"}
    else refuse_record("holds a row that is no row of the record")
    end;

def record_rows:
  written_rows as $rows
  | if $rows[0] != record_header then refuse_record("does not start with the header of the record")
    else $rows[1:] | map(row_of)
    end;

def unless_named_twice:
  if (map(.event) | unique | length) == length then . else refuse_record("names an event twice") end;

# The rows (the input) name the main sessions' lines and only those: each of them counts at least one event, and a
# line of a run counts none here (a run is counted once by its agent id).
def in_step_with($lines):
  ([$lines | to_entries[] | select(.value.role == main_role) | .key + 1]) as $main_lines
  | if (map(.line | numbers) | unique) == $main_lines then .
    else refuse("\(record_file) and ctxm/metrics/tasks.csv are out of step: a row names a line that is no main" +
      " session's line of tasks.csv, or a main session's line has no row; restore both from git")
    end;

def unless_one_without_the_other($tasks_text):
  if (. == "") == ($tasks_text == "") then .
  elif . == "" then refuse("ctxm/metrics/tasks.csv is there without \(record_file), the record of what its lines" +
    " counted; restore both from git")
  else refuse("\(record_file) is there without ctxm/metrics/tasks.csv; restore both from git")
  end;

# The events the record (the input: its text, empty when there is no file) holds, each by its key with the number
# of its line or `none`, once it has been checked against tasks.csv: its text and its lines.
def counted_events($tasks_text; $lines):
  unless_one_without_the_other($tasks_text)
  | if . == "" then {}
    else record_rows | unless_named_twice | in_step_with($lines)
      | map({key: .event, value: (.line // nothing)}) | from_entries
    end;

def record_row:
  (.event | index("/")) as $slash
  | [.line // nothing, .event[:$slash], .event[$slash + 1:]] | map(field_text) | join(",");

# The rows a collection adds (the input lists the outcomes that write a line, in the order of their lines): for each
# line, numbered on from the $count lines tasks.csv holds, the events it counts; then the events $passed (keys).
def new_rows($count; $passed):
  [to_entries[] | (.key + $count + 1) as $line | .value.events[]? | {line: $line, event: .}]
  + ($passed | map({line: null, event: .}));

# The record (the input: its text, empty when there is no file) with the rows added: what was there, byte for byte,
# then the new rows; the header first in a new file.
def with_rows_added($rows):
  (if . == "" then record_header else sub("\n\\z"; "") end) + "\n" + ($rows | map(record_row + "\n") | add // "");
