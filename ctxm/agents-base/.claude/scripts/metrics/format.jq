# The format of ctxm/metrics/, as docs/metrics-format.md of the template library defines it: the columns of
# tasks.csv, the fixed words, and what a value may look like. Everything written to ctxm/metrics/ passes through
# this file, and every value read from outside is checked against it before use.
# Pure. The modules are joined into one program (program.sh), so the others call these definitions.

def columns: [
  "task", "role", "session", "agent", "start", "end", "wall_seconds",
  "input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens", "compactions",
  "model", "effort", "project", "templates", "roles"
];

def header: columns | join(",");

# The fixed words. `none`: the line has no such thing (a main session has no task and no agent id). `unknown`: the
# value has no source. `main`: the role of a main session's line.
def nothing: "none";
def unknown: "unknown";
def main_role: "main";
def is_fixed_word: . == nothing or . == unknown or . == main_role;

# A main session is closed when none of its records is younger than this.
def quiet_seconds: 3600;

# A longer line of a transcript is not read.
def line_limit_bytes: 8388608;

# Whether the whole value fits the pattern. `$` would also accept a line break at the end, so the end is `\\z`.
def matches($pattern): type == "string" and test("\\A(?:\($pattern))\\z");

# A task name as the templates give them: a request id (with up to two prefixes) or a release version, then parts
# of letters and digits. Short parts, so a long random string is never taken for a name.
def is_task_name:
  matches("(([A-Z][A-Z0-9]{0,7}-){0,2}REQ-[0-9]{1,6}|v[0-9]{1,4}(\\.[0-9]{1,4}){1,2})(-[A-Za-z0-9]{1,24}){1,8}")
  and length <= 80;

def is_role: matches("[A-Za-z][A-Za-z0-9-]{0,39}") and (is_fixed_word | not);
def is_model: matches("[A-Za-z0-9][A-Za-z0-9._:\\[\\]-]{0,79}") and (is_fixed_word | not);
def is_effort: matches("[a-z][a-z0-9-]{0,19}") and (is_fixed_word | not);
def is_session_id: matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
def is_agent_id: matches("[0-9a-z]{1,64}") and (is_fixed_word | not);
def is_project_name: matches("[A-Za-z0-9][A-Za-z0-9._-]{0,63}") and (is_fixed_word | not);
def is_template_name: matches("[a-z0-9][a-z0-9-]{0,63}");
def is_library_commit: matches("[0-9a-f]{40}([0-9a-f]{24})?");

# A time in ctxm/metrics/: UTC, to the second.
def is_time:
  matches("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z")
  and . == (try (fromdateiso8601 | todate) catch null);
def time_text: todate;
def time_seconds: fromdateiso8601;

# A list in one field: the parts in order, joined by `+`; `none` for an empty list.
def listed: if length == 0 then nothing else sort | join("+") end;

# A refusal ends the collection: nothing is written, and the one line says why (collect-metrics.sh prints it).
def refuse($why): error({refusal: $why});

# The one place a line is written. A field holds only letters, digits and the marks the lists use, and starts with
# a letter or a digit: it can never hold a separator, a quote or a line break, nor start a spreadsheet formula.
def is_field: matches("[A-Za-z0-9][A-Za-z0-9._:@=/+\\[\\]-]*");
def field_text: tostring | if is_field then . else error("a value that is no field of tasks.csv reached a line") end;
def csv_line: . as $line | [columns[] | $line[.] | field_text] | join(",");

def by_column: [columns, .] | transpose | map({key: .[0], value: .[1]}) | from_entries;

def is_line: (.start | is_time) and (.end | is_time);

def line_of_fields:
  split(",") as $fields
  | if ($fields | length) == (columns | length) and all($fields[]; is_field) and ($fields | by_column | is_line)
    then $fields | by_column
    else refuse("ctxm/metrics/tasks.csv holds a line that is no line of the format; restore it from git")
    end;

# The lines tasks.csv holds (the input is its text, empty when there is no file), each as an object by column. A
# file with another header or a broken line is refused: the collector adds only to a file it can read.
def written_lines:
  if . == "" then []
  else sub("\n\\z"; "") | split("\n") as $rows
    | if $rows[0] != header
      then refuse("ctxm/metrics/tasks.csv does not start with the header of the format; restore it from git")
      else $rows[1:] | map(line_of_fields)
      end
  end;

# tasks.csv with the lines added: what was there, byte for byte, then the new lines; the header first in a new file.
def with_lines_added($lines):
  (if . == "" then header else sub("\n\\z"; "") end) + "\n" + ($lines | map(csv_line + "\n") | add);
