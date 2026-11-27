# shellcheck shell=bash
# The collector's tool requirement, and its refusal. The templates ship no toolchain: the project's own provides
# bash, jq, git and the five coreutils commands the collector calls. Sourced first by collect-metrics.sh, which
# calls require_tools before it reads anything.

readonly REQUIRED_TOOLS=(jq git ln mkdir mv rm wc)
# The status of a refusal inside the collector, so that its end tells a refusal (its line already said) from a step
# that failed; the collector itself exits 1 for both. Never a status a tool of the collector gives for its own
# failure (jq exits 1 to 5, git 128): a jq program that does not compile (3) would pass for a refusal.
readonly REFUSED_STATUS=70
# The status of a collector stopped by a signal (TERM, INT, HUP), for the same reason.
# shellcheck disable=SC2034 # read by collect-metrics.sh and telling.sh
readonly INTERRUPTED_STATUS=71

# Ends the collector with one `error:` line saying why.
refuse() {
  printf 'error: %s\n' "$*" >&2
  exit "$REFUSED_STATUS"
}

# Ends the collector with one line naming every required tool that is missing; returns when all are there.
require_tools() {
  local tool missing=()
  ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))) || missing+=("bash 4.4 or later")
  for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  ((${#missing[@]} == 0)) && return
  refuse "collect-metrics.sh needs $(comma_separated "${missing[@]}"): not on the PATH;" \
    "the project's toolchain must provide $(listed "bash 4.4 or later" "${REQUIRED_TOOLS[@]}")"
}

comma_separated() {
  local separated
  printf -v separated '%s, ' "$@"
  printf '%s\n' "${separated%, }"
}

# Prints the words as a list: commas, and `and` before the last.
listed() {
  local all_but_last=("${@:1:$#-1}")
  printf '%s and %s\n' "$(comma_separated "${all_but_last[@]}")" "${!#}"
}
