# shellcheck shell=bash
# The collector's tool requirement. The templates ship no toolchain: the project's own provides bash, jq, git and
# the three coreutils commands the collector calls. Sourced by collect-metrics.sh, which calls require_tools before
# it reads anything.

readonly REQUIRED_TOOLS=(jq git mkdir mv rm)
readonly REQUIREMENT="the project's toolchain must provide bash 4.4 or later, jq, git, mkdir, mv and rm"

refuse() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Ends the collector with one line naming every required tool that is missing; returns when all are there.
require_tools() {
  local tool missing=()
  ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))) || missing+=("bash 4.4 or later")
  for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  ((${#missing[@]} == 0)) && return
  refuse "collect-metrics.sh needs $(comma_separated "${missing[@]}"): not on the PATH; $REQUIREMENT"
}

comma_separated() {
  local separated
  printf -v separated '%s, ' "$@"
  printf '%s\n' "${separated%, }"
}
