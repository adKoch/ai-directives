#!/usr/bin/env bash
# Builds a synthetic project with a git history: each commit holds the lock ctxm writes (the applied templates) and
# the agent files (each role's model and effort), so a later commit can change the setup as a `ctxm update` does.
# Usage: make-project.sh <history.json> <project folder> <epoch>
#   <history.json>  the commits, each with its minute, lock and agents (tests/metrics/fixtures/projects/, README.md)
#   <epoch>         the time the history's minute 0 stands for, as 2026-01-05T09:00:00Z; give the transcripts of the
#                   same scenario the same one
# The folder must not hold a repository yet.
set -euo pipefail

SUPPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SUPPORT
# shellcheck source=files.sh
source "$SUPPORT/files.sh"

main() {
  readonly HISTORY=$1 PROJECT=$2 EPOCH=$3
  local count ordinal
  start_repository
  count="$(jq '.commits | length' "$HISTORY")"
  for ((ordinal = 0; ordinal < count; ordinal++)); do
    commit_state "$ordinal"
  done
}

start_repository() {
  if [[ -e "$PROJECT/.git" ]]; then
    printf 'error: %s already holds a repository; give make-project.sh a new folder\n' "$PROJECT" >&2
    exit 1
  fi
  mkdir -p "$PROJECT"
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git init --quiet --initial-branch=main "$PROJECT"
}

# Commits the state of one commit of the history: the work tree holds that commit's files and no others.
commit_state() {
  local ordinal=$1 files date
  files="$(commit_jq "$ordinal" commit_files --compact-output)"
  # shellcheck disable=SC2016 # $epoch is jq's
  date="$(commit_jq "$ordinal" 'commit_date($epoch)' --raw-output)"
  project_git rm -r --quiet --ignore-unmatch -- .
  write_files "$PROJECT" <<<"$files"
  project_git add --all
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    project_git commit --quiet --allow-empty --message "synthetic commit $ordinal"
}

# Prints what a filter of project.jq gives for one commit of the history.
commit_jq() {
  local ordinal=$1 filter=$2
  shift 2
  jq -L "$SUPPORT" --argjson ordinal "$ordinal" --arg epoch "$EPOCH" "$@" \
    "include \"project\"; .commits[\$ordinal] | $filter" "$HISTORY"
}

# git on the project's own repository and no other: the repository is named, never looked for from the current
# folder, and neither the user's nor the system's settings are read.
project_git() {
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$PROJECT" --git-dir=.git --work-tree=. \
    -c user.name=synthetic -c user.email=synthetic@example.invalid -c commit.gpgsign=false "$@"
}

main "$@"
