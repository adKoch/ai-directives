# Where a line of .ctxm/ctxm.lock ends: outside any string, or inside a multi-line string that a later line closes.
# toml writes a value holding a line break as a multi-line string (`"""`, or `'''` when the value holds `"""`), and
# a value holding quotes as one on a single line; ctxm takes any text for a project value, a default or a path. The
# collector reads none of those values, but it must know where each ends, so that no line inside one is ever read as
# a header or a key (setup.jq). Pure; needs nothing.

# The state where the rest of a line (the input) ends, given the state where it starts: null outside a string,
# `"""` or `'''` inside a multi-line string, `broken` when a one-line string is not closed on its line.
def line_end($state):
  def outside_strings:
    sub("\\A[^\"'#]*"; "") as $text
    | if $text == "" or ($text | startswith("#")) then null
      elif $text | startswith("\"\"\"") then $text[3:] | line_end("\"\"\"")
      elif $text | startswith("'''") then $text[3:] | line_end("'''")
      else ($text | capture("\\A(?:\"(?:[^\"\\\\]|\\\\.)*\"|'[^']*')(?<rest>.*)\\z") // {broken: true})
        | if .broken then "broken" else .rest | line_end(null) end
      end;
  # A multi-line string ends at its delimiter, with up to two quotes of the value before it; in a `"""` string a
  # backslash escapes the character after it, so `\"""` closes nothing.
  def after_close:
    if $state == "\"\"\"" then capture("\\A(?:[^\"\\\\]|\\\\.|\"(?!\"\"))*\"{3,5}(?<rest>.*)\\z")
    else capture("\\A(?:[^']|'(?!''))*'{3,5}(?<rest>.*)\\z")
    end
    | .rest;
  if $state == null then outside_strings
  else (after_close // null) as $rest | if $rest == null then $state else $rest | line_end(null) end
  end;
