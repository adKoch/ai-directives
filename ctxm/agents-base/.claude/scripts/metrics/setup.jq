# The setup a project had at one commit: its fingerprint, from the lock ctxm writes and the agent files there.
#   .ctxm/ctxm.lock          `version = 6` (the format ctxm 0.7 writes) and one [[templates]] table per applied
#                            template, with its `name` and the library `commit` it was applied at
#   .claude/agents/<role>.md the front matter's `model` and `effort`
# A commit gives one of three: a fingerprint, `absent` (no lock: the project was not on the templates), or a
# `problem` (a lock or an agent file the collector cannot read). A problem refuses the collection only when a
# line would need that setup (lines.jq), so an old commit never blocks a project.
# Pure; needs format.jq. Read from the bottom (setup) up.
# Adding a lock format: docs/metrics-format.md of the template library, "Adding a lock format".

def lock_version: "6";
def lock_file: ".ctxm/ctxm.lock";
def agent_file: "an agent file of .claude/agents/";

def table_entry: capture("^(?<key>name|commit)\\s*=\\s*\"(?<value>[^\"]*)\"\\s*$") // null;

def add_lock_line($line):
  if ($line | test("^\\[\\[templates\\]\\]\\s*$")) then .table = "templates" | .templates += [{}]
  elif ($line | test("^\\[")) then .table = "another"
  elif .table == null and ($line | test("^version\\s*=")) then .version = ($line | sub("^version\\s*=\\s*"; ""))
  elif .table == "templates" then ($line | table_entry) as $entry
    | if $entry == null then . else .templates[-1][$entry.key] = $entry.value end
  else .
  end;

# The version and the [[templates]] tables of a lock; every other table and key is skipped.
def read_lock: reduce split("\n")[] as $line ({table: null, version: null, templates: []}; add_lock_line($line));

def applied_template:
  if (.name | is_template_name) and (.commit | is_library_commit) then "\(.name)@\(.commit)"
  else error("\(lock_file) names a template or a library commit that is none")
  end;

def applied_templates:
  read_lock
  | if .version != lock_version
    then error("\(lock_file) is not in the lock format ctxm 0.7 writes (version \(lock_version))")
    else .templates | map(applied_template) | listed
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

def fingerprint($lock; $agents):
  ($agents | map(role_setup)) as $roles
  | {
      templates: ($lock | applied_templates),
      roles: ($roles | map("\(.role)=\(.model)/\(.effort)") | listed),
      efforts: ($roles | map({key: .role, value: .effort}) | from_entries)
    };

# The setup of one commit. $lock is null when the commit has no lock; $agents lists {role, text}, one per agent
# file. A problem names the commit and the file's place, never a value read from them.
def setup($commit; $since; $lock; $agents):
  {kind: "setup", commit: $commit, since: $since}
  + if $lock == null then {absent: true}
    else try {fingerprint: fingerprint($lock; $agents)}
      catch {problem: "the setup at commit \($commit): \(.)"}
    end;
