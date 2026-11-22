#!/usr/bin/env bash
# The lint step of scripts/check.sh: shellcheck on every shell file under the folders that hold the library's shell
# code. A sourced file is followed from the folder of the file that sources it.
# shellcheck source=../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# The library's scripts, the tests, and the scripts agents-base ships to projects.
readonly SHELL_FOLDERS=(scripts tests ctxm/agents-base/.claude/scripts)

main() {
  local folder files=()
  shopt -s globstar nullglob dotglob
  for folder in "${SHELL_FOLDERS[@]}"; do
    files+=("$REPO_ROOT/$folder"/**/*.sh)
  done
  ((${#files[@]} > 0)) || die "no shell file found under: ${SHELL_FOLDERS[*]}"
  shellcheck --external-sources --source-path=SCRIPTDIR "${files[@]}"
  printf '%s shell files pass shellcheck\n' "${#files[@]}"
}

main
