# shellcheck shell=bash
# What a test file sources. A test file is `<subject>.test.sh`; scripts/check.sh runs every one. It sources this
# file, defines its tests and ends with `run_tests`:
#   # catches: <the break this test exists for>
#   test_<a_sentence_about_the_subject>() { ...; assert_equal "$actual" "$expected"; }
# Each test runs in a shell of its own, inside an empty folder of its own (its `$PWD`), with errexit on: its first
# failing command fails it. The folders sit outside the checkout and are removed when the file ends.

set -euo pipefail

LIBRARY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
readonly LIBRARY_ROOT
# shellcheck disable=SC2034 # read by the test files
readonly SUPPORT="$LIBRARY_ROOT/tests/metrics/support" FIXTURES="$LIBRARY_ROOT/tests/metrics/fixtures"

# Runs every `test_` function of the file that called it, prints one line per test (and a failed test's output),
# and ends the file with 1 when a test failed, or when the file has no test.
run_tests() {
  local name names
  mapfile -t names < <(declared_tests)
  ((${#names[@]} > 0)) || fail "$0 has no test_ function; no test was run"
  SCRATCH_ROOT="$(mktemp -d)"
  FAILED_TESTS=0
  trap 'rm -rf "$SCRATCH_ROOT"' EXIT
  trap 'exit 143' TERM
  for name in "${names[@]}"; do
    run_test "$name"
  done
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

fail() {
  printf '%s\n' "$*" >&2
  return 1
}

assert_equal() {
  local actual=$1 expected=$2
  [[ "$actual" == "$expected" ]] || fail "expected: $expected"$'\n'"  actual: $actual"
}

assert_starts_with() {
  local text=$1 start=$2
  [[ "$text" == "$start"* ]] || fail "expected to start with: $start"$'\n'"               actual: $text"
}
