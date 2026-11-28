#!/usr/bin/env bash
# How the comparison ends when its text cannot reach stdout or its rules fail, and that its own files hold no
# character a terminal or a reader would not show as it is. Each ends with 0 or 1 and at most one line on stderr.
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"
# shellcheck source=../../../scripts/lib/hidden-characters.sh
source "$REPO_ROOT/scripts/lib/hidden-characters.sh"

# What the comparison calls, but jq; sleep is the budget's (scripts/lib/budget.sh).
readonly TOOLS_BUT_JQ=(bash dirname basename wc timeout sleep)
readonly RULES_FAILED='the rules of the comparison (scripts/compare/ and those of the collector, run by jq) failed,'\
' so nothing is shown; check that this library checkout is whole and that jq is the version README.md (Tools) names'
readonly NOT_WRITTEN="the text could not be written to stdout; give it a place to write that takes the whole text"

# catches: a comparison into a pipe nobody reads that ends with an error or a broken-pipe line.
test_a_comparison_into_a_closed_pipe_ends_quietly() {
  rolled_up_project alpha one-setup
  compare_into_a_closed_pipe alpha/project
  assert_prints 0 cat status
  assert_prints '' cat stderr
  assert_nothing_written
}

# catches: a comparison whose text was lost on a stdout that takes no byte, ending with 0 as if it had been shown.
test_a_comparison_that_cannot_write_its_text_ends_with_its_line() {
  rolled_up_project alpha one-setup
  compare_into_a_full_device alpha/project
  assert_prints 1 cat status
  assert_prints "error: $NOT_WRITTEN" cat stderr
  assert_nothing_written
}

# catches: a jq that fails ending the comparison with jq's own status and words, which may quote what it read,
# instead of exit 1 and one line.
test_a_jq_that_fails_ends_the_comparison_with_one_line() {
  local tool
  rolled_up_project alpha one-setup
  mkdir tools
  for tool in "${TOOLS_BUT_JQ[@]}"; do
    ln -s "$(command -v "$tool")" "tools/$tool"
  done
  printf '#!%s\nprintf "jq: error: synthetic-text\\n" >&2\nexit 5\n' "$(command -v bash)" >tools/jq
  chmod +x tools/jq
  COMPARISON_PATH="$PWD/tools" compare alpha/project
  assert_prints 1 cat status
  assert_prints "error: $RULES_FAILED" cat stderr
  assert_prints '' cat stdout
  assert_nothing_written
}

# catches: a hidden character (a right-to-left override, a control character) in the comparison's own files, where
# a reviewer cannot see it.
test_the_comparisons_files_hold_only_printable_ascii() {
  local files
  shopt -s dotglob nullglob
  files=("$REPO_ROOT"/scripts/compare-setups.sh "$REPO_ROOT"/scripts/compare/* "$REPO_ROOT"/docs/compare-setups.md
    "$REPO_ROOT"/tests/metrics/compare/*)
  assert_prints '' files_outside_printable_ascii "${files[@]}"
}

# catches: a misnamed rule module reported as a failure of the rules, hiding the line that names it.
test_a_misnamed_rule_module_is_named_in_the_line() {
  local status=0
  bash -c 'source "$1/scripts/lib/common.sh"; source "$1/scripts/compare/program.sh"; comparison_jq nowhere/reading . --null-input' \
    _ "$REPO_ROOT" >stdout 2>stderr || status=$?
  assert_equal "$status" 1
  assert_prints 'error: no rule module nowhere/reading: name it collector/<name> or compare/<name>' cat stderr
}

run_tests
