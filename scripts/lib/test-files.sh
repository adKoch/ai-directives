# shellcheck shell=bash
# The library's test files, each named: a file found only by a pattern could vanish unnoticed, and so could one that
# ends before it has run its tests. Every file named here must be present and every `*.test.sh` under scripts/ and
# tests/ named here; a new test file is added here. Sourced after common.sh.

readonly TEST_FILES=(
  scripts/lib/tests/check.test.sh
  scripts/lib/tests/hidden-characters.test.sh
  scripts/lib/tests/test-files.test.sh
  tests/metrics/support/project.test.sh
  tests/metrics/support/testing.test.sh
  tests/metrics/collector/copies.test.sh
  tests/metrics/collector/format.test.sh
  tests/metrics/collector/record.test.sh
  tests/metrics/collector/refusals.test.sh
  tests/metrics/collector/runs.test.sh
  tests/metrics/collector/sessions.test.sh
  tests/metrics/collector/start.test.sh
  tests/metrics/collector/store.test.sh
  tests/metrics/collector/text.test.sh
  tests/metrics/compare/help.test.sh
  tests/metrics/compare/output.test.sh
  tests/metrics/compare/refusals.test.sh
  tests/metrics/compare/side-by-side.test.sh
  tests/metrics/rollup/figures.test.sh
  tests/metrics/rollup/refusals.test.sh
  tests/metrics/rollup/writing.test.sh
  tests/metrics/support/transcripts.test.sh
)

# Ends the script with one line naming the listed test files that are missing and the test files found that are not
# listed; returns when the list and the checkout agree.
require_test_files() {
  local found missing unlisted
  mapfile -t found < <(found_test_files)
  missing="$(files_absent "${TEST_FILES[@]}")"
  unlisted="$(files_unlisted "${found[@]}")"
  [[ -z "$missing$unlisted" ]] && return
  die "test files missing: ${missing:-none}; not in scripts/lib/test-files.sh: ${unlisted:-none};" \
    "restore or list them; no test was run"
}

# Prints the test files under scripts/ and tests/, from the library's root, one per line.
found_test_files() {
  local files=()
  shopt -s globstar nullglob
  files=("$REPO_ROOT"/scripts/**/*.test.sh "$REPO_ROOT"/tests/**/*.test.sh)
  ((${#files[@]} == 0)) || printf '%s\n' "${files[@]#"$REPO_ROOT"/}"
}

files_absent() {
  local file absent=()
  for file in "$@"; do
    [[ -f "$REPO_ROOT/$file" ]] || absent+=("$file")
  done
  printf '%s' "${absent[*]}"
}

files_unlisted() {
  local file unlisted=()
  for file in "$@"; do
    [[ " ${TEST_FILES[*]} " == *" $file "* ]] || unlisted+=("$file")
  done
  printf '%s' "${unlisted[*]}"
}

# Runs one test file as a program of its own; the file prints its results. Fails when the file fails, and when it
# ended without having run its tests (no `run_tests` at its end, an early `exit 0`): run_tests then wrote no report.
run_test_file() {
  local file=$1 report=$2
  rm -f -- "$report"
  LIBRARY_TEST_REPORT="$report" bash "$file" || return 1
  [[ -s "$report" ]] && return
  printf 'error: %s ended before it ran its tests; it must end with run_tests\n' "${file#"$REPO_ROOT"/}" >&2
  return 1
}
