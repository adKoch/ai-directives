#!/usr/bin/env bash
# The test step of scripts/check.sh: runs every test file (`*.test.sh`) under scripts/ and tests/, each as a program
# of its own. A test file prints its own results and fails when one of its tests does
# (tests/metrics/support/testing.sh).
# shellcheck source=../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

main() {
  local files=() file failed=0
  shopt -s globstar nullglob
  files=("$REPO_ROOT"/scripts/**/*.test.sh "$REPO_ROOT"/tests/**/*.test.sh)
  # A pattern that finds nothing must not pass for a run of the tests.
  ((${#files[@]} > 0)) || die "no test file found under scripts/ and tests/; no test was run"
  for file in "${files[@]}"; do
    printf '%s\n' "${file#"$REPO_ROOT"/}"
    bash "$file" || failed=$((failed + 1))
  done
  ((failed == 0)) || die "$failed of ${#files[@]} test files failed"
}

main
