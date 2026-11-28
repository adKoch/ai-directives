#!/usr/bin/env bash
# An empty tasks.csv or record (0 bytes) is refused only where its partner is full: then one of the two was lost
# (record.test.sh). Everywhere else an empty file reads as one that is not there, as it always has: both empty, one
# empty and the other missing, and the first collection, which reads neither.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

# Builds a project collected once from finished-run and keeps its tasks.csv and record in ./whole/.
collected_project_kept() {
  rm -rf project transcripts whole
  started_project one-setup
  transcripts finished-run
  collected
  mkdir whole
  cp "$METRICS/tasks.csv" "$METRICS/counted.csv" whole/
}

# Empties each named file of ctxm/metrics/ (tasks.csv, counted.csv).
empty_files() {
  local file
  for file in "$@"; do
    : >"$METRICS/$file"
  done
}

# catches: an empty tasks.csv or record refused with no full partner beside it ("restore it from git"): those runs
# collected before the empty file had words of its own, and a fresh collection writes the lines and the record anew.
test_an_empty_lines_file_or_record_with_no_full_partner_is_collected_anew() {
  local emptied
  for emptied in 'tasks.csv counted.csv' tasks.csv counted.csv; do
    collected_project_kept
    rm "$METRICS/tasks.csv" "$METRICS/counted.csv"
    # shellcheck disable=SC2086 # the word lists the files to empty
    empty_files $emptied
    collected
    assert_same_content "$METRICS/tasks.csv" whole/tasks.csv
    assert_same_content "$METRICS/counted.csv" whole/counted.csv
  done
}

# catches: a first collection refused for an empty tasks.csv or record, its partner full or not: it reads neither,
# so it starts the metrics and leaves both as they stand, as it did before the empty file had words of its own.
test_the_first_collection_starts_the_metrics_beside_an_empty_lines_file_or_record() {
  local emptied
  for emptied in tasks.csv counted.csv 'tasks.csv counted.csv'; do
    collected_project_kept
    rm "$METRICS/start"
    # shellcheck disable=SC2086 # the word lists the files to empty
    empty_files $emptied
    cp "$METRICS/tasks.csv" "$METRICS/counted.csv" whole/
    collected
    assert_prints 'counted.csv
start
tasks.csv' metrics_files
    assert_same_content "$METRICS/tasks.csv" whole/tasks.csv
    assert_same_content "$METRICS/counted.csv" whole/counted.csv
  done
}

run_tests
