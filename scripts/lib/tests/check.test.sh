#!/usr/bin/env bash
# What every library script does before its own work: it checks its tools and takes its time budget.
# shellcheck source=../../../tests/metrics/support/testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../tests/metrics/support/testing.sh"

# What scripts/check.sh calls before it has checked its tools, and its listed tools without shellcheck.
readonly TOOLS_WITHOUT_SHELLCHECK=(bash dirname basename jq git timeout)

# catches: a check that lints or tests although a listed tool is missing, or whose line no longer names the tool.
test_without_shellcheck_the_check_names_it_and_runs_nothing() {
  local tool status=0
  mkdir tools
  for tool in "${TOOLS_WITHOUT_SHELLCHECK[@]}"; do
    ln -s "$(command -v "$tool")" "tools/$tool"
  done
  PATH="$PWD/tools" "$BASH" "$LIBRARY_ROOT/scripts/check.sh" >stdout 2>stderr || status=$?
  assert_equal "$status" 1
  assert_equal "$(<stderr)" \
    'error: scripts/check.sh needs shellcheck: not on the PATH; README.md (Tools) lists the tools to provide'
  assert_equal "$(<stdout)" ''
}

# catches: a script over its budget that leaves a process it started running, or that stops without the line
# naming its budget.
test_a_script_over_its_budget_is_stopped_with_what_it_started() {
  local status=0
  env --unset=LIBRARY_WITHIN_BUDGET LIBRARY_BUDGET_SECONDS=1 \
    "$LIBRARY_ROOT/scripts/lib/tests/standins/over-budget.sh" "$PWD/started.pid" >stdout 2>stderr || status=$?
  assert_equal "$status" 1
  assert_equal "$(<stderr)" 'error: scripts/lib/tests/standins/over-budget.sh stopped: over its budget of 1s'\
' (LIBRARY_BUDGET_SECONDS sets it)'
  if kill -0 "$(<started.pid)" 2>/dev/null; then
    fail "the process the script started still runs"
  fi
}

run_tests
