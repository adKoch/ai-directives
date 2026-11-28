# shellcheck shell=bash
# How the comparison runs its rules: jq modules of two folders, the collector's (the roll-up format, written once) and
# this one's, joined into one program in the order given, a module after the ones it needs (jq 1.8 cannot let one
# module include another). The joining is the collector's own (`joined_modules`, metrics/program.sh); only the
# folders and the refusals are this one's.
# Sourced by compare-setups.sh; needs REPO_ROOT and die (scripts/lib/common.sh).

readonly COLLECTOR_RULES="$REPO_ROOT/ctxm/agents-base/.claude/scripts/metrics"
readonly COMPARISON_RULES="$REPO_ROOT/scripts/compare"
# shellcheck source=../../ctxm/agents-base/.claude/scripts/metrics/program.sh
source "$COLLECTOR_RULES/program.sh"
readonly RULES_FAILED='the rules of the comparison (scripts/compare/ and those of the collector, run by jq) failed,'\
' so nothing is shown; check that this library checkout is whole and that jq is the version README.md (Tools) names'

# Runs jq on a filter that calls the definitions of the named modules, each `collector/<name>` or `compare/<name>`;
# the jq options and files follow. A module that cannot be read, or a jq that fails, ends the comparison with one
# line: jq's own words are not shown, as they may quote what it read. A misnamed module says so.
#   comparison_jq "collector/format compare/reading" 'read_rollup($plan)' --raw-input --slurp --arg plan x <file>
comparison_jq() {
  local modules=$1 filter=$2 module path paths=() program
  shift 2
  for module in $modules; do
    path="$(module_path "$module")" || exit 1
    paths+=("$path")
  done
  program="$(joined_modules "${paths[@]}" 2>/dev/null)" || die "$RULES_FAILED"
  jq "$program"$'\n'"$filter" "$@" 2>/dev/null || die "$RULES_FAILED"
}

# Prints the path of a module without its `.jq`.
module_path() {
  case "$1" in
    collector/*) printf '%s/%s\n' "$COLLECTOR_RULES" "${1#collector/}" ;;
    compare/*) printf '%s/%s\n' "$COMPARISON_RULES" "${1#compare/}" ;;
    *) die "no rule module $1: name it collector/<name> or compare/<name>" ;;
  esac
}
