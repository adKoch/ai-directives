#!/usr/bin/env bash
# The test step of scripts/check.sh: runs every test file named in scripts/lib/test-files.sh, each as a program of
# its own, after checking that the list and the checkout agree. A test file prints its own results and fails when
# one of its tests does (tests/metrics/support/testing.sh). The last line counts the files and the tests run, and the
# tests skipped where they could not check what they are for, so a skip shows in check.sh's summary.
# shellcheck source=../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
# shellcheck source=../test-files.sh
source "$REPO_ROOT/scripts/lib/test-files.sh"

readonly REPORT_FILE="$CACHE_DIR/check/tests-run"

main() {
  local file tests=0 skipped=0 failed=0 ran skipped_here
  require_test_files
  make_cache_folder check
  for file in "${TEST_FILES[@]}"; do
    printf '%s\n' "$file"
    if run_test_file "$REPO_ROOT/$file" "$REPORT_FILE"; then
      read -r ran skipped_here <"$REPORT_FILE"
      tests=$((tests + ran))
      skipped=$((skipped + skipped_here))
    else
      failed=$((failed + 1))
    fi
  done
  ((failed == 0)) || die "$failed of ${#TEST_FILES[@]} test files failed"
  tests_summary "${#TEST_FILES[@]}" "$tests" "$skipped"
}

main
