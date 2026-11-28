#!/usr/bin/env bash
# The test step runs every named test file and counts only the files that ran their tests to the end.
# shellcheck source=../../../tests/metrics/support/testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../tests/metrics/support/testing.sh"
# shellcheck source=../test-files.sh
source "$REPO_ROOT/scripts/lib/test-files.sh"

# catches: a test file that ends before run_tests (its last line forgotten, an early `exit 0`) counted as passed:
# its tests would never run and the check would still say ok.
test_a_test_file_that_never_reaches_run_tests_fails() {
  local status=0 shown="${PWD#"$REPO_ROOT"/}/unfinished.test.sh"
  printf 'source "%s/testing.sh"\ntest_never_run() { :; }\n' "$SUPPORT" >unfinished.test.sh
  run_test_file "$PWD/unfinished.test.sh" "$PWD/report" >stdout 2>stderr || status=$?
  assert_equal "$status" 1
  assert_prints "error: $shown ended before it ran its tests; it must end with run_tests" \
    cat stderr
}

# catches: a test step whose last line, the one check.sh shows, says nothing of the tests skipped, so a run where a
# test could not check what it is for reads as one where every test did.
test_the_summary_counts_the_skipped_tests_and_names_none_when_none_was() {
  assert_prints '24 test files, 150 tests passed, 2 of them skipped (see the test lines)' tests_summary 24 150 2
  assert_prints '24 test files, 150 tests passed' tests_summary 24 150 0
}

run_tests
