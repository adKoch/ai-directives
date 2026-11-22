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

run_tests
