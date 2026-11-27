# What the roll-ups read besides tasks.csv, as facts: a plan file's items, the commits of each item, the release
# candidates. Each is read from text of the project's own (a plan, git's log, a file name) and gives numbers, task
# names and versions that pass format.jq, nothing else. Pure; needs format.jq. Read from the bottom up.

# A plan's item headings: an item's bold title, then its task name in backticks in parentheses, as
# **1A standard-worker: the title** (task `REQ-900-1A-first-example`) or **T-1 release-tester** (`v0.8-T-1`).
def item_task_names: [scan("\\*\\* \\((?:task\\s+)?`([^`\\n]{1,80})`") | .[0] | select(is_task_name)] | unique;

# The facts of a plan file (the input is its text, no longer than plans.sh lets through): its name, when the plan
# file was first committed (seconds, or null), and the task names of its item headings: the plan's items. A task
# named anywhere else in the text (a dependency, a done list) is no item of it. A plan with another name is left
# out.
def plan_facts($name; $first):
  if ($name | is_plan_name)
  then {kind: "plan", name: $name, first_commit: $first, items: item_task_names}
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
