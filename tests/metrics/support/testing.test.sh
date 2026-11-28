#!/usr/bin/env bash
# What a test file can rely on from testing.sh: an assertion fails when the command it checks fails.
# shellcheck source=testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/testing.sh"

# catches: an assertion that passes when its command fails but prints the expected value, as a failed search
# prints what a search that found nothing prints: every test of "nothing found" would pass without searching.
test_an_assertion_fails_when_its_command_fails_after_printing_the_expected_value() {
  local status=0
  write_test_file_of_failing_searches checked.test.sh
  bash checked.test.sh >output 2>&1 || status=$?
  assert_equal "$status" 1
  assert_prints '["  FAILED  a function that fails before its end","  FAILED  a pipeline whose first step fails"]' \
    result_lines output
}

# Writes a test file whose two tests check a search that fails but prints `[]`: once as a pipeline, once as a
# function whose failing command is not its last.
write_test_file_of_failing_searches() {
  cat >"$1" <<TEST_FILE
source "$SUPPORT/testing.sh"
search_in_a_pipeline() { jq -n -c 'not_a_definition' | jq -s -c .; }
search_in_steps() { false; printf '[]\n'; }
test_a_pipeline_whose_first_step_fails() { assert_prints '[]' search_in_a_pipeline; }
test_a_function_that_fails_before_its_end() { assert_prints '[]' search_in_steps; }
run_tests
TEST_FILE
}

# Prints the result line of each test, in the order the tests ran: by name.
result_lines() {
  jq -R -s -c '[splits("\n") | select(test("^  (ok|FAILED)  "))]' "$1"
}

# catches: a skipped test shown as passed, and counted as one in the test step's summary, so a run where a test could
# not check what it is for looks the same as one where it did.
test_a_skipped_test_is_shown_and_reported_as_skipped() {
  local status=0
  cat >skipping.test.sh <<TEST_FILE
source "$SUPPORT/testing.sh"
test_a_test_that_cannot_run_here() { skip_test "synthetic reason"; false; }
test_a_test_that_runs() { true; }
run_tests
TEST_FILE
  LIBRARY_TEST_REPORT="$PWD/report" bash skipping.test.sh >output 2>&1 || status=$?
  assert_equal "$status" 0
  assert_prints '  skipped a test that cannot run here: synthetic reason
  ok      a test that runs' cat output
  assert_prints '2 1' cat report
}

# catches: a skip read back from what a test prints: a test that prints a line like a skip's shown as skipped; and a
# skip inside `$(…)` or a pipeline that ends only that part while the test goes on and passes, also where the test
# masks the part's status.
test_only_skip_test_itself_marks_a_test_skipped_and_never_from_inside_a_substitution() {
  local status=0 misuse="skip_test ends only the test itself: call it outside \$(…) and pipelines"
  write_test_file_of_misplaced_skips skipping.test.sh
  bash skipping.test.sh >output 2>&1 || status=$?
  assert_equal "$status" 1
  assert_prints '["  ok      a test that prints a line like a skip",'\
'"  FAILED  a test that skips inside a masked substitution","  FAILED  a test that skips inside a pipeline",'\
'"  FAILED  a test that skips inside a substitution","  FAILED  a test that skips where its status is ignored"]' \
    result_lines output
  assert_prints "$misuse" uniq_lines_starting_skip_test output
}

# Writes a test file whose tests print a line like a skip's, or call skip_test inside a substitution or a pipeline:
# assigned, masked by `local`, ignored by `|| true`, and piped.
write_test_file_of_misplaced_skips() {
  cat >"$1" <<TEST_FILE
source "$SUPPORT/testing.sh"
test_a_test_that_prints_a_line_like_a_skip() { printf 'skipped: synthetic reason\n'; }
test_a_test_that_skips_inside_a_substitution() { local reason; reason="\$(skip_test "synthetic reason")"; }
test_a_test_that_skips_inside_a_masked_substitution() { local reason="\$(skip_test "synthetic reason")"; }
test_a_test_that_skips_where_its_status_is_ignored() { printf '%s' "\$(skip_test "synthetic reason")" || true; }
test_a_test_that_skips_inside_a_pipeline() { skip_test "synthetic reason" | cat; }
run_tests
TEST_FILE
}

# Prints the lines of the file that start with `skip_test`, each once, and fails unless there are 4.
uniq_lines_starting_skip_test() {
  local count
  count="$(grep --count '^skip_test' "$1")"
  ((count == 4)) || fail "expected 4 misuse lines, found $count"
  grep '^skip_test' "$1" | sort -u
}

run_tests
