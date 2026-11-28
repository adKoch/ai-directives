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

# The renames of these tests, in order: the roll-up, the record, tasks.csv (the last).
readonly LAST_RENAME=3

# Makes the collector's mv stop at its n-th call (the second when n is left out), the way the word says
# (standins/stopping-mv.sh).
with_mv_stopping_the_rename() {
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/stopping-mv.sh" tools/mv
  printf '%s\n' "$1 ${2:-2}" >tools/mv-stop
}

# Fails unless ctxm/metrics/ holds the start, the lines, their record and the roll-up, each as it was in ./before/.
assert_old_files_kept() {
  assert_prints 'REQ-900.md
counted.csv
start
tasks.csv' metrics_files
  assert_same_content "$METRICS/REQ-900.md" before/REQ-900.md
  assert_same_content "$METRICS/tasks.csv" before/tasks.csv
  assert_same_content "$METRICS/start" before/start
  assert_same_content "$METRICS/counted.csv" before/counted.csv
}

# Collects with the collector's mv stopping its n-th call (the second when n is left out) the way the word says.
collect_with_mv_stopping() {
  with_mv_stopping_the_rename "$1" "${2:-}"
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
}

# catches: a collection interrupted right after a rename returns, before it has noted it, leaving that file new: a
# roll-up that counts lines tasks.csv does not hold.
test_a_collection_interrupted_right_after_its_last_rename_puts_every_file_back() {
  project_collected_once
  collect_with_mv_stopping interrupt-after "$LAST_RENAME"
  assert_prints 'error: the collection was interrupted; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints 6 cat tools/mv-calls # the three renames, then the three put back
  assert_old_files_kept
}

# catches: a collection interrupted between two renames, the later one not done, leaving the first file new.
test_a_collection_interrupted_between_two_renames_puts_every_file_back() {
  project_collected_once
  collect_with_mv_stopping interrupt-before
  assert_prints 'error: the collection was interrupted; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints 3 cat tools/mv-calls
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
  collect_with_mv_stopping fail
  assert_prints 'mv: synthetic failure
error: a step of the collection failed, see above; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints 'counted.csv
start
tasks.csv' metrics_files
  assert_same_content "$METRICS/tasks.csv" before.csv
}

# catches: the old file of a place that could not be put back removed while the error line names it (the only copy
# of those bytes), or more than one error line, or one that claims nothing is half-written.
test_a_restore_that_fails_keeps_the_old_bytes_where_its_one_error_line_says() {
  local kept
  project_collected_once
  collect_with_mv_stopping fail-from-then-on
  kept="$(cd "$METRICS" && printf '%s\n' REQ-900.md.old.*)"
  assert_same_content "$METRICS/$kept" before/REQ-900.md
  assert_prints "mv: synthetic failure
mv: synthetic failure
error: the collection stopped and could not put back ctxm/metrics/REQ-900.md (its old bytes are in $kept); move\
 each old file over its file; the next collection refuses while one is left" cat stderr
  assert_same_content "$METRICS/tasks.csv" before/tasks.csv
}

# catches: the line of a roll-up that was new and could not be removed again promising a refusal that does not come: it
# leaves no old file, so the next collection runs.
test_a_new_rollup_that_cannot_be_removed_again_is_named_without_a_refusal_to_come() {
  started_project one-setup
  commit_plan REQ-900 "$PLAN_TEXT"
  transcripts reviewed-items
  with_mv_stopping_the_rename fail
  ln -s "$COLLECTOR_TESTS/standins/failing-rm-of-rollup.sh" tools/rm
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
  assert_prints "mv: synthetic failure
rm: synthetic failure
error: the collection stopped and could not put back ctxm/metrics/REQ-900.md (new; remove it, it was not there before)" cat stderr
  collected
}

# catches: a later collection that removes an old file a stopped collector kept, or writes over the place it
# belongs to, before a person has settled it.
test_an_old_file_a_stopped_collector_kept_stops_the_next_collection_and_stays() {
  local dead
  project_collected_once
  sleep 0 &
  dead=$!
  wait "$dead"
  printf 'old bytes\n' >"$METRICS/REQ-900.md.old.$dead"
  collect
  assert_prints 1 cat status
  assert_prints "error: ctxm/metrics/ holds 1 old file(s) a stopped collection kept, the first REQ-900.md.old.$dead;\
 move each over its file (the name without .old.<process id>), or remove it once its file is right; nothing was written" cat stderr
  assert_prints 'old bytes' cat "$METRICS/REQ-900.md.old.$dead"
  assert_same_content "$METRICS/REQ-900.md" before/REQ-900.md
  assert_same_content "$METRICS/tasks.csv" before/tasks.csv
}

# catches: the old files a collection keeps while it renames left behind once it is done, or a collection that
# renames nothing at all.
test_a_collection_that_is_done_leaves_only_its_files() {
  project_collected_once
  collected
  assert_prints 'REQ-900.md
counted.csv
start
tasks.csv' metrics_files
  # shellcheck disable=SC2016 # $now and $before are jq's
  assert_prints true jq --null-input --raw-output --rawfile now "$METRICS/tasks.csv" --rawfile before before/tasks.csv \
    '$now != $before and ($now | startswith($before))'
}

run_tests
