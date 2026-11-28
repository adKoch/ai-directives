#!/usr/bin/env bash
# The lint step of scripts/check.sh: shellcheck on every shell file under the folders that hold the library's own
# scripts and tests and the scripts agents-base ships; then no test file gives an assertion a command's output; then no
# file of the library holds a character a reader cannot see as it is (hidden-characters.sh). A sourced file is followed
# from the folder of the file that sources it.
# Not linted yet: the rest of ctxm/, whose hook ctxm/ctxm/.claude/hooks/ctxm-guard.sh fails SC2016.
# shellcheck source=../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
# shellcheck source=../test-files.sh
source "$REPO_ROOT/scripts/lib/test-files.sh"
# shellcheck source=../hidden-characters.sh
source "$REPO_ROOT/scripts/lib/hidden-characters.sh"

readonly SHELL_FOLDERS=(scripts tests ctxm/agents-base/.claude/scripts)
# An assertion given `$(…)` on its line; testing.sh says why that form passes when its command fails.
readonly OUTPUT_IN_ASSERTION='(^|[^a-z_])assert_[a-z_]+ .*\$\('

main() {
  local shell_files test_files checked_files
  mapfile -t shell_files < <(found_shell_files)
  ((${#shell_files[@]} > 0)) || die "no shell file found under: ${SHELL_FOLDERS[*]}"
  shellcheck --external-sources --source-path=SCRIPTDIR "${shell_files[@]}"
  mapfile -t test_files < <(found_test_files)
  require_assertions_run_their_commands "${test_files[@]}"
  mapfile -d '' -t checked_files < <(files_of_the_library "$REPO_ROOT")
  require_no_hidden_characters "${checked_files[@]}"
  printf '%s shell files pass shellcheck; %s test files give no assertion a command output;' \
    "${#shell_files[@]}" "${#test_files[@]}"
  printf ' %s files hold no hidden character\n' "${#checked_files[@]}"
}

found_shell_files() {
  local folder files=()
  shopt -s globstar nullglob dotglob
  for folder in "${SHELL_FOLDERS[@]}"; do
    files+=("$REPO_ROOT/$folder"/**/*.sh)
  done
  ((${#files[@]} == 0)) || printf '%s\n' "${files[@]}"
}

# Ends the step naming each line of the test files (from the library's root) that gives an assertion `$(…)`.
require_assertions_run_their_commands() {
  local file number line found=()
  for file in "$@"; do
    number=0
    while IFS= read -r line; do
      number=$((number + 1))
      [[ ! "$line" =~ $OUTPUT_IN_ASSERTION ]] || found+=("$file:$number")
    done <"$REPO_ROOT/$file"
  done
  ((${#found[@]} == 0)) || die "an assertion is given a command's output at ${found[*]};" \
    "use assert_prints <expected> <command> (tests/metrics/support/testing.sh)"
}

# Ends the step naming each file given that holds a hidden character; none given is a step that checked nothing.
require_no_hidden_characters() {
  local found
  (($# > 0)) || die "no file of the library found to check for hidden characters"
  found="$(files_with_hidden_characters "$@")"
  [[ -z "$found" ]] || die "hidden characters (control, zero-width or bidi) in: ${found//$'\n'/ }; remove them"
}

main
