#!/usr/bin/env bash
# What the collector does where it may not write: a collection with a file to write is refused in one line naming
# the folder, at each place the write would land, and writes nothing; one with nothing to write passes.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

# Takes write permission from the folder, and gives it back when the test ends, so its folder can be removed.
lock_folder() {
  ((EUID != 0)) || skip_test "root may write in a folder without write permission"
  LOCKED_FOLDER=$1
  trap 'chmod u+w "$LOCKED_FOLDER"' EXIT
  chmod a-w "$1"
}

# Fails unless the last collection was refused, in one line, because it may not write in the folder named.
assert_refused_for_writing_in() {
  assert_prints 1 cat status
  assert_prints "error: the collector may not write in $1; let it write there, ctxm/metrics/ is its only place;\
 nothing was written" cat stderr
  assert_prints '' cat stdout
}

# catches: a metrics folder the collector may not write met with the shell's own line before the error line (a
# place printed as it is), instead of one refusal.
test_a_metrics_folder_the_collector_may_not_write_is_refused_in_one_line() {
  started_project one-setup
  transcripts finished-run
  lock_folder "$METRICS"
  collect
  assert_refused_for_writing_in ctxm/metrics/
  assert_prints '?? ctxm/metrics/start' written_files
}

# catches: a first collection that may not make ctxm/metrics/ in a ctxm/ folder it may not write met with mkdir's
# own words instead of one refusal.
test_a_first_collection_in_a_ctxm_folder_it_may_not_write_is_refused_in_one_line() {
  project one-setup
  transcripts finished-run
  mkdir project/ctxm
  lock_folder project/ctxm
  collect
  assert_refused_for_writing_in ctxm/
  assert_prints '' written_files
}

# catches: a first collection that may not make ctxm/ in a project folder it may not write met with mkdir's own
# words instead of one refusal.
test_a_first_collection_in_a_project_folder_it_may_not_write_is_refused_in_one_line() {
  project one-setup
  transcripts finished-run
  lock_folder project
  collect
  assert_refused_for_writing_in 'the project folder'
  assert_prints '' written_files
}

# catches: the write check refusing a collection that has nothing to write, which passes in a metrics folder the
# collector may not write: no line to add and no roll-up.
test_a_collection_with_nothing_to_write_passes_in_a_metrics_folder_it_may_not_write() {
  started_project one-setup
  transcripts finished-run
  collected
  lock_folder "$METRICS"
  collected
  assert_prints '' cat stderr
  assert_prints 'ctxm/metrics/tasks.csv: lines added: 0 (of runs: 0, of main sessions: 0)' cat stdout
}

run_tests
