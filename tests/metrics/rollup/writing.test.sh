#!/usr/bin/env bash
# How a collection writes its roll-ups and its lines: all or nothing. A collection stopped or failing after it has
# renamed some of its files into place leaves every file of ctxm/metrics/ with the bytes it had before.
# shellcheck source=rolling.sh
source "$(dirname "${BASH_SOURCE[0]}")/rolling.sh"

# Builds a project collected once with the runs that had finished by minute 30, its files kept in ./before/, and
# the transcripts grown to all the runs: the next collection replaces the roll-up and tasks.csv.
project_collected_once() {
  started_project one-setup
  commit_plan REQ-900 "$PLAN_TEXT"
  transcripts reviewed-items 30
  collected
  mkdir before
  cp "$METRICS"/* before/
  transcripts reviewed-items
}

# Makes the collector's mv stop at its second rename, the way the word says (standins/stopping-second-mv.sh).
with_mv_stopping_its_second_rename() {
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/stopping-second-mv.sh" tools/mv
  printf '%s\n' "$1" >tools/mv-stop
}

# Fails unless ctxm/metrics/ holds the start, the lines and the roll-up, each as it was in ./before/.
assert_old_files_kept() {
  assert_prints 'REQ-900.md
start
tasks.csv' ls "$METRICS"
  assert_same_content "$METRICS/REQ-900.md" before/REQ-900.md
  assert_same_content "$METRICS/tasks.csv" before/tasks.csv
  assert_same_content "$METRICS/start" before/start
}

# catches: a collection interrupted after its first rename leaving that file new and the rest old: a roll-up that
# counts lines tasks.csv does not hold.
test_a_collection_interrupted_after_its_first_rename_puts_every_file_back() {
  project_collected_once
  with_mv_stopping_its_second_rename interrupt
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
  assert_prints 'error: the collection was interrupted; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints 4 cat tools/mv-calls
  assert_old_files_kept
}

# catches: a second rename that fails (a full disk, a read-only folder) leaving the first file renamed, or a roll-up
# that was not there before.
test_a_failing_second_rename_puts_every_file_back_and_writes_no_new_rollup() {
  started_project one-setup
  transcripts reviewed-items 30
  collected
  cp "$METRICS/tasks.csv" before.csv
  commit_plan REQ-900 "$PLAN_TEXT"
  transcripts reviewed-items
  with_mv_stopping_its_second_rename fail
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
  assert_prints 'mv: synthetic failure
error: a step of the collection failed, see above; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints 'start
tasks.csv' ls "$METRICS"
  assert_same_content "$METRICS/tasks.csv" before.csv
}

# catches: the old files a collection keeps while it renames left behind once it is done, or a collection that
# renames nothing at all.
test_a_collection_that_is_done_leaves_only_its_files() {
  project_collected_once
  collected
  assert_prints 'REQ-900.md
start
tasks.csv' ls "$METRICS"
  # shellcheck disable=SC2016 # $now and $before are jq's
  assert_prints true jq --null-input --raw-output --rawfile now "$METRICS/tasks.csv" --rawfile before before/tasks.csv \
    '$now != $before and ($now | startswith($before))'
}

run_tests
