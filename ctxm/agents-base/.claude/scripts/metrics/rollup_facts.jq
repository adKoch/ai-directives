# What the roll-ups read besides tasks.csv, as facts: a plan file's items, the commits of each item, the release
# candidates. Each is read from text of the project's own (a plan, git's log, a file name) and gives numbers, task
# names and versions that pass format.jq, nothing else. Pure; needs format.jq. Read from the bottom up.

# A plan file is read whole; a longer one is left out.
def plan_limit_bytes: 4194304;

def task_names_between_backticks: [scan("`([^`\\n]{1,80})`") | .[0] | select(is_task_name)] | unique;

# The facts of a plan file (the input is its text): its name, when the plan file was first committed (seconds, or
# null), and the task names between backticks in its text: the plan's items. A plan with another name or too long
# is left out.
def plan_facts($name; $first):
  if ($name | is_plan_name) and utf8bytelength <= plan_limit_bytes
  then {kind: "plan", name: $name, first_commit: $first, items: task_names_between_backticks}
  else {kind: "plan", name: null}
  end;

# The commits of git's log (the inputs: `C<tab><subject>` for a commit, then its `--numstat` rows), added up for
# each task a subject names: what stands before its first `: `, when that is a task name.
def subject_task: [split(": ")[0] | select(is_task_name)] | first;

def numstat_of($row): [$row | capture("\\A(?<added>[0-9]+|-)\\t(?<deleted>[0-9]+|-)\\t")] | first;

def no_commits: {commits: 0, added: 0, deleted: 0};

def opened_by($row):
  .task = ($row[2:] | subject_task)
  | if .task == null then . else .tasks[.task] |= ((. // no_commits) | .commits += 1) end;

# A binary file's `-` counts for nothing.
def counted_by($stat):
  if .task == null then .
  else .tasks[.task] |= (.added += (($stat.added | tonumber?) // 0) | .deleted += (($stat.deleted | tonumber?) // 0))
  end;

def add_row($row):
  if $row | startswith("C\t") then opened_by($row)
  else numstat_of($row) as $stat | if $stat == null then . else counted_by($stat) end
  end;

def commit_facts:
  reduce inputs as $row ({task: null, tasks: {}}; add_row($row))
  | .tasks | to_entries | map({kind: "commits", task: .key} + .value) | .[];

# The release candidates the names of ctxm/releases/ (the inputs) say: `v<x.y.z>-rc.<n>.md`.
def candidate_facts:
  inputs
  | [capture("\\Av(?<version>[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4})-rc\\.(?<n>[0-9]{1,4})\\.md\\z")] | first
  | select(. != null) | {kind: "candidate", version, n: (.n | tonumber)};
