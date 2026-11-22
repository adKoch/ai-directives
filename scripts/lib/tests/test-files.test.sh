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

run_tests
