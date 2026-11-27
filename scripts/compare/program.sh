# shellcheck shell=bash
# How the comparison runs its rules: jq modules of two folders, the collector's (the roll-up format, written once)
# and this one's, joined into one program in the order given, a module after the ones it needs (jq 1.8 cannot let
# one module include another). The collector's own seam (metrics/program.sh) reads only its folder.
# Sourced by compare-setups.sh; needs REPO_ROOT and die (scripts/lib/common.sh).

readonly COLLECTOR_RULES="$REPO_ROOT/ctxm/agents-base/.claude/scripts/metrics"
readonly COMPARISON_RULES="$REPO_ROOT/scripts/compare"
readonly RULES_FAILED='the rules of the comparison (scripts/compare/ and those of the collector, run by jq) failed,'\
' so nothing is shown; check that this library checkout is whole and that jq is the version README.md (Tools) names'

# Runs jq on a filter that calls the definitions of the named modules, each `collector/<name>` or `compare/<name>`;
# the jq options and files follow. A module that cannot be read, or a jq that fails, ends the comparison with one
# line: jq's own words are not shown, as they may quote what it read.
#   comparison_jq "collector/format compare/reading" 'read_rollup($plan)' --raw-input --slurp --arg plan x <file>
comparison_jq() {
  local modules=$1 filter=$2 program
  shift 2
  program="$(joined_modules "$modules" 2>/dev/null)" || die "$RULES_FAILED"
  jq "$program"$'\n'"$filter" "$@" 2>/dev/null || die "$RULES_FAILED"
}

# Prints the text of the named modules, in that order; fails at the first that cannot be read.
joined_modules() {
  local module text
  for module in $1; do
    text="$(<"$(module_file "$module")")" || return 1
    printf '%s\n' "$text"
  done
}

module_file() {
  case "$1" in
    collector/*) printf '%s/%s.jq\n' "$COLLECTOR_RULES" "${1#collector/}" ;;
    compare/*) printf '%s/%s.jq\n' "$COMPARISON_RULES" "${1#compare/}" ;;
    *) die "no rule module $1: name it collector/<name> or compare/<name>" ;;
  esac
}
