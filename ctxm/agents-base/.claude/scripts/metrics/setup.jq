# The setup a project had at one commit: its fingerprint, from the lock ctxm writes and the agent files there.
#   .ctxm/ctxm.lock          `version = 6` to `8` and one [[templates]] table per applied template, with its `name`
#                            and the library `commit` it was applied at; from format 8 also its released `version`
#                            when the template is pinned to one (formats 6 and 7 have none)
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

def table_entry: capture("^(?<key>name|version|commit)\\s*=\\s*\"(?<value>[^\"]*)\"\\s*$") // null;

# A key of a template that is no well-formed entry, or is given twice, marks the template: it is refused, never read
# as a template without that key (a missing version would pass for a commit pin).
def add_template_key($line):
  ($line | table_entry) as $entry
  | if $entry == null or (.templates[-1] | has($entry.key)) then .templates[-1].malformed = true
    else .templates[-1][$entry.key] = $entry.value
    end;

def add_lock_line($line):
  if ($line | test("^\\[\\[templates\\]\\]\\s*$")) then .table = "templates" | .templates += [{}]
  elif ($line | test("^\\[")) then .table = "another"
  elif .table == null and ($line | test("^version\\s*=")) then .version = ($line | sub("^version\\s*=\\s*"; ""))
  elif .table == "templates" and ($line | test("^(name|version|commit)\\s*=")) then add_template_key($line)
  else .
  end;

# The version and the [[templates]] tables of a lock; every other table and key is skipped.
def read_lock: reduce split("\n")[] as $line ({table: null, version: null, templates: []}; add_lock_line($line));

def lock_problem($what): error("\(lock_file) \($what)");

# A lock before format 8: the template's one library commit, no version.
def commit_template:
  if .version != null then lock_problem("names a template version in a lock format that has none")
  elif .commit | is_library_commit then "\(.name)@\(.commit)"
  else lock_problem("names a template or a library commit that is none")
  end;

# Format 8: a version pin names its released version and the commit the release named (the full id); a commit pin
# names a library commit, which may be abbreviated. A commit id is lowercase in the fingerprint, as git prints it.
def version_template:
  (.commit // "" | ascii_downcase) as $commit
  | if .version == null then
      if .commit | is_pinned_commit then "\(.name)@\($commit)" else lock_problem("names a library commit that is none") end
    elif (.version | is_template_version) and (.commit | is_released_commit) then "\(.name)@\(.version)@\($commit)"
    else lock_problem("names a template version or a library commit that is none")
    end;

def applied_template($format):
  if .malformed or (.name | is_template_name | not) then lock_problem("names a template or a library commit that is none")
  elif $format == version_lock_format then version_template
  else commit_template
  end;

# The order the lock lists the templates in is the order they were applied in, and a later template wins over an
# earlier one: so the order is part of the fingerprint, and the same templates in another order are another setup.
def applied_order: if length == 0 then nothing else join("+") end;

def applied_templates:
  read_lock
  | .version as $format
  | if $format | IN(commit_lock_formats[], version_lock_format)
    then .templates | map(applied_template($format)) | applied_order
    else lock_problem("is not in a lock format the collector reads (versions 6 to 8)")
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
