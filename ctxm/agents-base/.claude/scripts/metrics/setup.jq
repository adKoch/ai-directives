# The setup a project had at one commit: its fingerprint, from the lock ctxm writes and the agent files there.
#   .ctxm/ctxm.lock          `version = 6` to `8` and one [[templates]] table per applied template, with its `name`,
#                            `source` and the library `commit` it was applied at; from format 8 also its released
#                            `version` when the template is pinned to one (formats 6 and 7 have none)
#   .claude/agents/<role>.md the front matter's `model` and `effort`
# A commit gives one of three: a fingerprint, `absent` (no lock: the project was not on the templates), or a
# `problem` (a lock or an agent file the collector cannot read). A problem refuses the collection only when a
# line would need that setup (lines.jq), and only until a later commit has a setup without one (with_fixes_noted),
# so an old commit never blocks a project.
# Pure; needs format.jq. Read from the bottom (with_fixes_noted, setup) up.
# Adding a lock format: tests/metrics/collector/README.md of the template library, "Adding a lock format".

# The formats that pin a template to one library commit (6 is what ctxm 0.7 writes) and the one that may pin it to a
# released version (8, ctxm 0.8). Any other is refused, a future one included.
def commit_lock_formats: ["6", "7"];
def version_lock_format: "8";
def lock_file: ".ctxm/ctxm.lock";
def agent_file: "an agent file of .claude/agents/";

def lock_problem($what): error("\(lock_file) \($what)");

# The collector reads no TOML but the lines ctxm writes, and fails closed on any other: a line it skipped could hold a
# template or a key of one (an indented, quoted or dotted `version`), and the fingerprint would name another setup.
def unread_line:
  lock_problem("holds a line the collector does not read: a table, a key or a form ctxm does not write, or a key twice");

# The headers of the tables ctxm writes besides [[templates]], exactly; the lines of those tables are not read.
def other_tables: ["[[files]]", "[values]", "[defaults]"];

def is_skipped_line: test("\\A[ \\t]*(#.*)?\\z");

# A key of a template on its own line, as ctxm writes it: no indent, no quotes around the key, a string without an
# escape, nothing after it.
def template_entry:
  capture("\\A(?<key>name|source|version|commit)[ \\t]*=[ \\t]*\"(?<value>[^\"\\\\]*)\"[ \\t]*\\z") // unread_line;

# A key before the first table: the format's version, a number, and the folders, which are not read.
def top_entry:
  if test("\\Afolders[ \\t]*=[ \\t]*\\[.*\\][ \\t]*\\z") then {key: "folders", value: true}
  else capture("\\A(?<key>version)[ \\t]*=[ \\t]*(?<value>[0-9]+)[ \\t]*\\z") // unread_line
  end;

# A key given twice is refused, as ctxm refuses it: the first and the last would be two answers.
def add_entry($entry): if has($entry.key) then unread_line else .[$entry.key] = $entry.value end;

# A multi-line string could hold a line that reads as a header, so a lock with one is refused; ctxm writes none.
def add_lock_line($line):
  if $line | is_skipped_line then .
  elif $line | test("\"\"\"|'''") then unread_line
  elif $line == "[[templates]]" then .table = "templates" | .templates += [{}]
  elif $line | IN(other_tables[]) then .table = "another"
  elif $line | test("\\A[ \\t]*\\[") then unread_line
  elif .table == null then .top |= add_entry($line | top_entry)
  elif .table == "templates" then .templates[-1] |= add_entry($line | template_entry)
  else .
  end;

# The format's version and the [[templates]] tables of a lock. A line ends at a line feed, with or without a carriage
# return before it, as TOML reads it.
def read_lock:
  gsub("\r\n"; "\n") | split("\n")
  | reduce .[] as $line ({table: null, top: {}, templates: []}; add_lock_line($line))
  | {version: .top.version, templates};

# A commit pin names a library commit, which may be abbreviated, in every format, as ctxm checks it. A commit id is
# lowercase in the fingerprint, as git prints it, so a lock of ctxm 0.7 gives the form it always gave.
def commit_template:
  if .commit | is_pinned_commit then "\(.name)@\(.commit | ascii_downcase)"
  else lock_problem("names a library commit that is none")
  end;

# A version pin (format 8) names its released version and the full commit id the release named.
def version_template:
  if (.version | is_template_version) and (.commit | is_released_commit)
  then "\(.name)@\(.version)@\(.commit | ascii_downcase)"
  else lock_problem("names a template version or a library commit that is none")
  end;

def applied_template($format):
  if .name | is_template_name | not then lock_problem("names a template or a library commit that is none")
  elif .source | is_template_source | not then lock_problem("names a template without a source")
  elif .version == null then commit_template
  elif $format == version_lock_format then version_template
  else lock_problem("names a template version in a lock format that has none")
  end;

# The order the lock lists the templates in is the order they were applied in, and a later template wins over an
# earlier one: so the order is part of the fingerprint, and the same templates in another order are another setup.
def applied_order: if length == 0 then nothing else join("+") end;

def applied_templates:
  read_lock
  | .version as $format
  | if $format | IN(commit_lock_formats[], version_lock_format) | not then
      lock_problem("is not in a lock format the collector reads (versions 6 to 8)")
    elif (.templates | map(.name) | unique | length) < (.templates | length) then lock_problem("names a template twice")
    else .templates | map(applied_template($format)) | applied_order
    end;

# The lines between the first two `---` of an agent file.
def front_matter: split("\n") | if .[0] == "---" then .[1:] | .[:(index("---") // 0)] else [] end;

def front_value($key): [front_matter[] | capture("^\($key):\\s*(?<value>.*?)\\s*$").value] | first;

# A value the agent file does not name is unknown; one that is no plain word is a problem, never copied.
def plain(is_plain; $what):
  if . == null then unknown elif is_plain then . else error("\(agent_file) names \($what) that is no plain word") end;

def role_setup:
  .text as $text
  | {
      role: (.role | if is_role then . else error("\(agent_file) has a name that is no role") end),
      model: ($text | front_value("model") | plain(is_model; "a model")),
      effort: ($text | front_value("effort") | plain(is_effort; "an effort"))
    };

# An agent file opens with front matter, as Claude Code's subagents do; another file there (a README.md) is no role.
# A name git had to quote (an empty role) stays, so that it is refused.
def is_agent_file: .role == "" or (.text | split("\n") | .[0] == "---");

def fingerprint($lock; $agents):
  ($agents | map(select(is_agent_file) | role_setup)) as $roles
  | {
      templates: ($lock | applied_templates),
      roles: ($roles | map("\(.role)=\(.model)/\(.effort)") | listed),
      efforts: ($roles | map({key: .role, value: .effort}) | from_entries)
    };

# What a person can do about a setup with a problem: its commit cannot change, a later one can fix the files.
def problem_advice: "fix it in a new commit: what ran under this one is then counted on stderr, not written";

# The setup of one commit. $lock is null when the commit has no lock; $agents lists {role, text}, one per agent
# file. A problem names the commit and the file's place, never a value read from them.
def setup($commit; $since; $lock; $agents):
  {kind: "setup", commit: $commit, since: $since}
  + if $lock == null then {absent: true}
    else try {fingerprint: fingerprint($lock; $agents)}
      catch {problem: "the setup at commit \($commit): \(.); \(problem_advice)"}
    end;

# The setups of a project (the input, newest first), each with a problem marked `fixed_later` when a newer one has
# none: what ran under it can never be written and no person can change that commit, so it is counted instead of
# refusing every collection for as long as its transcripts last.
def with_fixes_noted:
  . as $setups
  | to_entries
  | map(.value + if .value.problem and any($setups[:.key][]; .problem == null) then {fixed_later: true} else {} end);
