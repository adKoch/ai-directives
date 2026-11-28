# shellcheck shell=bash
# What a test file sources. A test file is `<subject>.test.sh`, named in scripts/lib/test-files.sh, which
# scripts/check.sh runs. It sources this file, defines its tests and ends with `run_tests`:
#   # catches: <the break this test exists for>
#   test_<a_sentence_about_the_subject>() { ...; assert_prints "$expected" <command>; }
# Each test runs in a shell of its own, inside an empty folder of its own (its `$PWD`), with errexit on: its first
# failing command fails it, also inside a command substitution that is assigned. A substitution given as an argument
# hides its command's status, so an assertion never takes `$(…)`: `assert_prints` runs the command itself, and the
# lint step refuses the other form. The folders sit in the checkout's ignored cache (.cache/tests/), a set of its own
# for each run of a test file, and are removed when the file ends.

# shellcheck source=../../../scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/lib/common.sh"
shopt -s inherit_errexit

# shellcheck disable=SC2034 # read by the test files
readonly SUPPORT="$REPO_ROOT/tests/metrics/support" FIXTURES="$REPO_ROOT/tests/metrics/fixtures"
# Where the test step learns that this file ran its tests to the end (scripts/lib/test-files.sh). Taken out of the
# environment, so a test file that a test runs reports to nobody.
readonly TEST_REPORT="${LIBRARY_TEST_REPORT:-}"
unset LIBRARY_TEST_REPORT

# Runs every `test_` function of the file that called it, prints one line per test (and a failed test's output),
# reports how many ran, and ends the file with 1 when a test failed, or when the file has no test.
run_tests() {
  local name names
  mapfile -t names < <(declared_tests)
  ((${#names[@]} > 0)) || fail "$0 has no test_ function; no test was run"
  make_cache_folder tests
  SCRATCH_ROOT="$(mktemp -d "$CACHE_DIR/tests/run.XXXXXX")"
  FAILED_TESTS=0
  trap 'rm -rf "$SCRATCH_ROOT"' EXIT
  trap 'exit 143' TERM
  for name in "${names[@]}"; do
    run_test "$name"
  done
  report_tests_run "${#names[@]}"
  ((FAILED_TESTS == 0)) || exit 1
}

# Prints the names of the file's test functions, in the order of their names.
declared_tests() {
  local name
  while read -r _ _ name; do
    [[ "$name" != test_* ]] || printf '%s\n' "$name"
  done < <(declare -F)
}

# Adds a failed test to FAILED_TESTS. The test is a command of its own, in no `||` or `if`, and so is every call on
# the way to it: only so does errexit hold inside the test.
run_test() {
  local name=$1 folder="$SCRATCH_ROOT/$1" status
  mkdir "$folder"
  set +e
  (
    set -e
    cd "$folder"
    "$name"
  ) >"$folder.output" 2>&1
  status=$?
  set -e
  ((status == 0)) || FAILED_TESTS=$((FAILED_TESTS + 1))
  print_test_result "$name" "$status" "$folder.output"
}

print_test_result() {
  local sentence="${1#test_}" status=$2 output=$3
  if ((status == 0)); then
    printf '  ok      %s\n' "${sentence//_/ }"
  else
    printf '  FAILED  %s\n' "${sentence//_/ }"
    cat "$output"
  fi
}

report_tests_run() {
  [[ -z "$TEST_REPORT" ]] || printf '%s\n' "$1" >"$TEST_REPORT"
}

fail() {
  printf '%s\n' "$*" >&2
  return 1
}

assert_equal() {
  local actual=$1 expected=$2
  [[ "$actual" == "$expected" ]] || fail "expected: $expected"$'\n'"  actual: $actual"
}

# Runs the command and fails unless it succeeds and prints the expected text. Errexit holds inside the command, so a
# function fails at its first failing command, and a search that fails fails here, though it prints what a search
# that found nothing prints.
assert_prints() {
  local expected=$1 actual status
  shift
  set +e
  actual="$(
    set -e
    "$@"
  )"
  status=$?
  set -e
  ((status == 0)) || fail "failed with status $status: $*"
  [[ "$actual" == "$expected" ]] || fail "expected: $expected"$'\n'"  actual: $actual"$'\n'"    from: $*"
}

# Fails unless both files are there and hold the same text.
assert_same_content() {
  local actual expected
  actual="$(<"$1")"
  expected="$(<"$2")"
  assert_equal "$actual" "$expected"
}

# Fails unless both files are there and the first starts with the whole of the second.
assert_starts_with_content() {
  local text start
  text="$(<"$1")"
  start="$(<"$2")"
  [[ "$text" == "$start"* ]] || fail "$1 does not start with the content of $2"
}
