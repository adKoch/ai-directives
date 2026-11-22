# shellcheck shell=bash
# The tool requirement of the library's scripts (README.md, Tools). Sourced by common.sh.

# Ends the script with one line naming every command of the list that is not on the PATH; returns when all are there.
# Nothing has run yet when it ends: a script calls it before its first step.
require_tools() {
  local tool missing=()
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  ((${#missing[@]} == 0)) && return
  die "$(shown_script_path) needs $(comma_separated "${missing[@]}"): not on the PATH;" \
    "README.md (Tools) lists the tools to provide"
}

comma_separated() {
  local separated
  printf -v separated '%s, ' "$@"
  printf '%s\n' "${separated%, }"
}
