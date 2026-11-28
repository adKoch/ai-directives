#!/usr/bin/env bash
# The library's minimal check, within a time budget: shellcheck on the library's scripts and tests and on the scripts
# agents-base ships, and no hidden character in any file (lint; the rest of ctxm/ not yet shellchecked,
# scripts/lib/steps/lint.sh), then every test file (test). It
# checks its tools first and runs nothing without them: the caller's toolchain provides them (README.md, Tools).
# Usage: scripts/check.sh
#   LIBRARY_BUDGET_SECONDS=<n> sets the budget in seconds (300 by default).
# Prints one line per step (result, time, what it covered) and the total; a failed step's output follows on stderr
# and stays in .cache/check/<step>.log. Exits 0 when every step passed, 1 otherwise (a missing tool, a failed step,
# a budget stop).
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_tools bash jq shellcheck git timeout sleep
ensure_budget "$@"

readonly LOG_DIR="$CACHE_DIR/check"
readonly STEPS=(lint test)

main() {
  local step failed=0
  make_cache_folder check
  for step in "${STEPS[@]}"; do
    run_step "$step" || failed=$((failed + 1))
  done
  print_step total '' "${SECONDS}s of $(budget_seconds)s"
  ((failed == 0)) || die "$failed step(s) failed"
}

# A step is a script of its own (scripts/lib/steps/<step>.sh), so its first failing command ends it. A passed step's
# last line says what it covered, so a step that covered less than it should shows in the summary.
run_step() {
  local step=$1 log="$LOG_DIR/$1.log" started=$SECONDS
  if bash "$REPO_ROOT/scripts/lib/steps/$step.sh" >"$log" 2>&1; then
    print_step "$step" ok "$((SECONDS - started))s: $(tail -n 1 "$log")"
  else
    print_step "$step" FAILED "$((SECONDS - started))s (${log#"$REPO_ROOT"/})"
    cat "$log" >&2
    return 1
  fi
}

print_step() {
  printf '%-8s %-8s %s\n' "$@"
}

main
