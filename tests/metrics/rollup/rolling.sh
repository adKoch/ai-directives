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
# The plan of the shapes here: two items and a final test, named between backticks, among free text.
# shellcheck disable=SC2034,SC2016 # read by the test files; the backticks are the plan's own
readonly PLAN_TEXT='synthetic-text the plan. Items: `REQ-900-1A-first-example`, `REQ-900-1B-second-example`,
`REQ-900-T1-final-test`, and `not a task` or `REQ-900-1C-never-ran` with no runs.'

# Commits a file of the project at a time, with a message of the test's own: git as a user with no settings.
commit_file() {
  local date=$1 message=$2 path=$3 content=$4
  mkdir -p "project/${path%/*}"
  printf '%s\n' "$content" >"project/$path"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git -C project -c user.name=synthetic -c user.email=synthetic@example.invalid -c commit.gpgsign=false \
    add --all
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git -C project -c user.name=synthetic -c user.email=synthetic@example.invalid -c commit.gpgsign=false \
    commit --quiet --message "$message"
}

# Commits the plan of that name, first committed at PLAN_DATE.
commit_plan() {
  commit_file "$PLAN_DATE" "synthetic-text the plan" "ctxm/plans/$1.md" "$2"
}
