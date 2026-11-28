#!/usr/bin/env bash
# What a person does with a project collected before ctxm/metrics/counted.csv existed: the comparison and the
# collector both refuse it, and each names the way out that works (docs/metrics-format.md, Starting again).
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"

readonly EARLIER_FILES='earlier-metrics/REQ-900.md
earlier-metrics/start
earlier-metrics/tasks.csv'

# Turns alpha's metrics into what a collector before the record left: tasks.csv without counted.csv, and a roll-up
# whose layout is not the current one (its title line gone).
make_alpha_collected_before_the_record() {
  rm alpha/project/ctxm/metrics/counted.csv
  sed -i 1d "alpha/project/$ROLLUP_FILE"
}

# Prints the files of the metrics moved out of alpha's project, in the order of their bytes.
earlier_files() {
  find earlier-metrics -type f | LC_ALL=C sort
}

# catches: a refusal whose advice cannot be followed for a project collected before counted.csv existed: the
# comparison says to collect again, the collector then refuses with "restore both from git", and nothing says how
# to go on.
test_a_project_collected_before_the_record_existed_can_start_its_metrics_again_as_both_refusals_say() {
  rolled_up_project alpha one-setup
  make_alpha_collected_before_the_record
  compare alpha/project
  assert_prints 1 cat status
  assert_prints 'Starting again' grep --only-matching 'Starting again' stderr
  cd alpha
  collect
  assert_prints 1 cat status
  assert_prints 'Starting again' grep --only-matching 'Starting again' stderr
  mv project/ctxm/metrics earlier-metrics
  collect
  assert_prints 0 cat status
  assert_prints start ls "$METRICS"
  assert_prints "$EARLIER_FILES" earlier_files
  assert_prints '## Starting again' grep '^## Starting again$' "$REPO_ROOT/docs/metrics-format.md"
}

run_tests
