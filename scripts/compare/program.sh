# shellcheck shell=bash
# How the comparison runs its rules: jq modules of two folders, the collector's (the roll-up format, written once)
# and this one's, joined into one program in the order given, a module after the ones it needs (jq 1.8 cannot let
# one module include another). The collector's own seam (metrics/program.sh) reads only its folder.
# Sourced by compare-setups.sh; needs REPO_ROOT (scripts/lib/common.sh).

readonly COLLECTOR_RULES="$REPO_ROOT/ctxm/agents-base/.claude/scripts/metrics"
readonly COMPARISON_RULES="$REPO_ROOT/scripts/compare"

# Runs jq on a filter that calls the definitions of the named modules, each `collector/<name>` or `compare/<name>`;
# the jq options and files follow.
#   comparison_jq "collector/format compare/reading" 'read_rollup($plan)' --raw-input --slurp --arg plan x <file>
comparison_jq() {
  local modules=$1 filter=$2 module program=''
  shift 2
  for module in $modules; do
    program+="$(<"$(module_file "$module")")"$'\n'
  done
  jq "$program$filter" "$@"
}

module_file() {
  case "$1" in
    collector/*) printf '%s/%s.jq\n' "$COLLECTOR_RULES" "${1#collector/}" ;;
    compare/*) printf '%s/%s.jq\n' "$COMPARISON_RULES" "${1#compare/}" ;;
    *) die "no rule module $1: name it collector/<name> or compare/<name>" ;;
  esac
}
