# The format of ctxm/metrics/, as docs/metrics-format.md of the template library defines it: the columns of
# tasks.csv, the fixed words, and what a value may look like. Everything written to ctxm/metrics/ passes through
# this file, and every value read from outside is checked against it before use.
# Pure. The modules are joined into one program (program.sh), so the others call these definitions.

def columns: [
  "task", "role", "session", "agent", "start", "end", "wall_seconds",
  "input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens", "compactions",
  "model", "effort", "project", "templates", "roles", "blocking", "nits"
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

# A longer line of a transcript is no record: the transcript is left out (jq reads the line whole first).
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
# An API call's id (its message id) and a compaction's id (its record's uuid). The record of what the lines counted
# holds them (counted.jq), so each starts with a letter or a digit, as every field does.
def is_call_id: matches("[A-Za-z0-9][A-Za-z0-9_-]{0,127}");
def is_record_id: matches("[0-9a-f][0-9a-f-]{0,63}");
def is_project_name: matches("[A-Za-z0-9][A-Za-z0-9._-]{0,63}") and (is_fixed_word | not);
def is_template_name: matches("[a-z0-9][a-z0-9-]{0,63}");
def is_library_commit: matches("[0-9a-f]{40}([0-9a-f]{24})?");
# A plan is a file of ctxm/plans/, its roll-up ctxm/metrics/<plan>.md: letters and digits in parts joined by one `.`,
# `_` or `-`, so the name holds no `..`, no `/` and no leading dot.
def is_plan_name: matches("[A-Za-z0-9]+([._-][A-Za-z0-9]+){0,15}") and length <= 64;

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
# A number is written as its digits: jq keeps a number it read as it was written there (1E2, 10.0), and arithmetic
# gives the plain form.
def number_text:
  . + 0 | tostring
  | if matches("[0-9]{1,16}") then . else error("a number that is no count of tasks.csv reached a line") end;
def field_text:
  if type == "number" then number_text
  else tostring | if is_field then . else error("a value that is no field of tasks.csv reached a line") end
  end;
def csv_line: . as $line | [columns[] | $line[.] | field_text] | join(",");

def by_column: [columns, .] | transpose | map({key: .[0], value: .[1]}) | from_entries;

def is_line: (.start | is_time) and (.end | is_time);

# How many columns each header of the format named, the current one last: the first 17, then 19 with `blocking`
# and `nits`. Columns are only ever added at the end, so an earlier header is the current one cut after that many;
# a column added adds its width here.
def header_widths: [17, 19];

# How many columns a header names, when it is the header of this format or of an earlier one; null for any other
# header, a cut that never was a header included.
def header_width:
  . as $row | first(header_widths[] | select(columns[:.] | join(",") == $row)) // null;

# What a row of an earlier header lacks: the columns added since, each unknown (they had no source then).
def missing_fields($width): [range($width; columns | length) | unknown];

def widened($width): . + (missing_fields($width) | map("," + .) | add // "");

def line_of_fields($width):
  split(",") as $given
  | ($given + missing_fields($width)) as $fields
  | if ($given | length) == $width and all($fields[]; is_field) and ($fields | by_column | is_line)
    then $fields | by_column
    else refuse("ctxm/metrics/tasks.csv holds a line that is no line of the format; restore it from git")
    end;

def written_rows: sub("\n\\z"; "") | split("\n");

# The lines tasks.csv holds (the input is its text, empty when there is no file), each as an object by column. A
# file with another header or a broken line is refused: the collector adds only to a file it can read. A file under
# an earlier header is read with unknown in the columns added since.
def written_lines:
  if . == "" then []
  else written_rows as $rows
    | ($rows[0] | header_width) as $width
    | if $width == null
      then refuse("ctxm/metrics/tasks.csv does not start with the header of the format; restore it from git")
      else $rows[1:] | map(line_of_fields($width))
      end
  end;

# The text of tasks.csv (the input) under the header of the format: unchanged when it is there already, else
# each row widened, so that an old file is moved to the new header with every line kept.
def under_current_header:
  if . == "" then header
  else written_rows | (.[0] | header_width) as $width | [header] + (.[1:] | map(widened($width))) | join("\n")
  end;

# tasks.csv with the lines added: what was there, byte for byte, then the new lines; the header first in a new file.
def with_lines_added($lines):
  under_current_header + "\n" + ($lines | map(csv_line + "\n") | add);
