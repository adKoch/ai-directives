# shellcheck shell=bash
# What a roll-up test sources: collecting.sh, and the steps that give a project plans and commits. A test builds a
# project that has started its metrics, adds a plan, collects, and reads ctxm/metrics/<plan>.md:
#   started_project one-setup; commit_plan REQ-900 "$PLAN_TEXT"; transcripts reviewed-items; collected
#   assert_prints '| all | 7 | …' grep '^| all' "$METRICS/REQ-900.md"
# The shapes and histories of this folder come before the collector's own.

SCENARIOS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../collector/collecting.sh
source "$SCENARIOS/../collector/collecting.sh"

# The time a plan is first committed: after the project's history and the start, before the runs of the shapes.
readonly PLAN_DATE=2026-01-04T08:00:00Z
# The plan of the shapes here: two items, one that never ran and a final test, each under its item heading, among
# free text that names tasks too.
# shellcheck disable=SC2034,SC2016 # read by the test files; the backticks are the plan's own
readonly PLAN_TEXT='synthetic-text the plan.

**1A standard-worker: synthetic-text the first** (task `REQ-900-1A-first-example`)

**1B standard-worker: synthetic-text the second** (task
`REQ-900-1B-second-example`), after `REQ-900-1A-first-example`.

**1C standard-worker: synthetic-text never ran** (task `REQ-900-1C-never-ran`), with `not a task`.

**T1 release-tester** (`REQ-900-T1-final-test`)'

# Writes a file of the project.
put_file() {
  mkdir -p "project/${1%/*}"
  printf '%s\n' "$2" >"project/$1"
}

# Commits every change of the project at the time, with a message of the test's own.
commit_all() {
  project_git_at "$1" add --all
  project_git_at "$1" commit --quiet --message "$2"
}

# Runs git on the project at the time, as a user with no settings.
project_git_at() {
  local date=$1
  shift
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git -C project -c user.name=synthetic -c user.email=synthetic@example.invalid -c commit.gpgsign=false "$@"
}

# Commits the plan of that name, first committed at PLAN_DATE.
commit_plan() {
  put_file "ctxm/plans/$1.md" "$2"
  commit_all "$PLAN_DATE" "synthetic-text the plan"
}
