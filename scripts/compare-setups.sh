#!/usr/bin/env bash
# Compares template setups: reads the roll-ups the collector wrote into each project's ctxm/metrics/ and shows the
# setups side by side, by plan and by item. Reads nothing else and writes nothing.
# Usage and exit codes: compare/help.txt (what --help prints); the rules: docs/compare-setups.md.
# The layers: this file wires; compare/projects.sh reads (the port); compare/*.jq decide (the rules), joined with the
# collector's roll-up format by compare/program.sh.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_tools jq wc timeout dirname basename
ensure_budget "$@"
# shellcheck source=compare/program.sh
source "$REPO_ROOT/scripts/compare/program.sh"
# shellcheck source=compare/projects.sh
source "$REPO_ROOT/scripts/compare/projects.sh"

# The rules of a comparison, each after the ones it needs (compare/program.sh).
readonly COMPARISON_MODULES="collector/format collector/rollup collector/rollup_text compare/reading compare/figures
  compare/comparison_text compare/comparison"
readonly HELP_FILE="$REPO_ROOT/scripts/compare/help.txt"
readonly USAGE='usage: compare-setups.sh [--help] [--] <project folder>...; --help says more'
PROJECT_FOLDERS=()

main() {
  local facts result
  if asks_for_help "$@"; then
    result="$(<"$HELP_FILE")"
    print_result "$result"
    return
  fi
  read_project_folders "$@"
  find_rollups
  facts="$(rollup_facts)"
  result="$(comparison_result "$facts")"
  print_comparison "$result"
}

# Answers whether an argument before `--` is `--help`.
asks_for_help() {
  local argument
  for argument in "$@"; do
    [[ "$argument" != -- ]] || return 1
    [[ "$argument" != --help ]] || return 0
  done
  return 1
}

# Sets PROJECT_FOLDERS from the arguments, or ends with the usage line: an argument before `--` that starts with `-`
# is no folder.
read_project_folders() {
  while (($# > 0)) && [[ "$1" != -- ]]; do
    [[ "$1" != -* ]] || die "$USAGE"
    add_project_folder "$1"
    shift
  done
  (($# == 0)) || shift
  while (($# > 0)); do
    add_project_folder "$1"
    shift
  done
  ((${#PROJECT_FOLDERS[@]} > 0)) || die "$USAGE"
}

# Adds the folder to PROJECT_FOLDERS without its trailing slashes, so the places printed read as one path.
add_project_folder() {
  local folder=$1
  while [[ "$folder" == ?*/ ]]; do
    folder=${folder%/}
  done
  PROJECT_FOLDERS+=("$folder")
}

# Prints the comparison of the facts (compare/comparison.jq): {text} or {refusal}. The facts are gathered first, so
# a refusal while gathering them is the only line.
comparison_result() {
  printf '%s\n' "$1" | comparison_jq "$COMPARISON_MODULES" comparison --slurp --compact-output
}

# Prints the comparison's text, or ends with its refusal.
print_comparison() {
  local refusal text
  refusal="$(result_part '.refusal // empty' "$1")"
  [[ -z "$refusal" ]] || die "$refusal"
  text="$(result_part .text "$1")"
  print_result "$text"
}

result_part() {
  printf '%s\n' "$2" | comparison_jq '' "$1" --raw-output
}

# Prints the text on stdout. A closed stdout loses the text, quietly: nothing is left to do. Any other failed write
# ends the comparison with its line, as the text did not arrive. The C locale makes bash's word for the closed pipe
# the same in every locale.
print_result() {
  local LC_ALL=C failure=''
  trap '' PIPE
  { failure="$(printf '%s\n' "$1" 2>&1 >&3)"; } 3>&1 || true
  [[ -z "$failure" || "$failure" == *'Broken pipe' ]] \
    || die "the comparison could not be written to stdout; give it a place to write that takes the whole text"
}

main "$@"
