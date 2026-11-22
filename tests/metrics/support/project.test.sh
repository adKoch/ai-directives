#!/usr/bin/env bash
# The maker of synthetic projects builds the git history a fingerprint is read from.
# shellcheck source=testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/testing.sh"

readonly EPOCH=2026-01-05T09:00:00Z
readonly SPANNING_SHAPE="$FIXTURES/transcripts/session-across-template-update.json"

# catches: an update commit dated outside the session that is meant to span it, or one that leaves the lock as it
# was: the session then has one setup, and a test of "one line per setup" passes without a split.
test_the_template_update_falls_inside_the_session_that_spans_it_and_changes_the_lock() {
  local session=transcripts/ffffffff-0000-4000-8000-000000000001.jsonl update
  "$SUPPORT/make-project.sh" "$FIXTURES/projects/template-update.json" "$PWD/project" "$EPOCH"
  "$SUPPORT/make-transcripts.sh" "$SPANNING_SHAPE" "$PWD/transcripts" "$EPOCH"
  update="$(git -C project log -1 --format=%ct)"
  assert_prints '{"before":2,"after":2}' calls_on_each_side_of "$update" "$session"
  assert_prints 1111111111111111111111111111111111111111 locked_commit HEAD~1
  assert_prints 2222222222222222222222222222222222222222 locked_commit HEAD
  assert_prints medium inspector_effort HEAD~1
  assert_prints high inspector_effort HEAD
}

# Prints how many of the session's API calls began before the time (in seconds since 1970) and how many after it.
calls_on_each_side_of() {
  local time=$1 session=$2
  jq -s -c --argjson time "$time" '
    map(select(.type == "assistant")) | group_by(.message.id)
    | map(.[0].timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)
    | {before: map(select(. < $time)) | length, after: map(select(. > $time)) | length}
  ' "$session"
}

# Prints the library commit the lock names at a commit of the project; more than one when its templates differ.
locked_commit() {
  git -C project show "$1:.ctxm/ctxm.lock" \
    | jq -R -s -r '[scan("\\ncommit = \"([0-9a-f]+)\"")[]] | unique | join(" ")'
}

inspector_effort() {
  git -C project show "$1:.claude/agents/inspector.md" \
    | jq -R -s -r 'capture("\\neffort: (?<effort>[a-z]+)\\n").effort'
}

run_tests
