# shellcheck shell=bash
# How the collector runs its rules. The rules are jq definitions in modules beside this file, pure: they read their
# input and their arguments and write nothing. jq 1.8 cannot let one module include another, so the modules a filter
# needs are joined into one program, in the order given: a module comes after the ones it needs. The comparison
# (scripts/compare/program.sh) joins modules of two folders with the same `joined_modules`.

# Runs jq on a filter that calls the definitions of the named modules of this folder; the jq options and files follow.
#   metrics_jq "format facts" 'transcript_facts' --null-input --raw-input <file>
metrics_jq() {
  local modules=$1 filter=$2 module paths=() program
  shift 2
  for module in $modules; do
    paths+=("$METRICS_SCRIPTS/$module")
  done
  program="$(joined_modules "${paths[@]}")" || return 1
  jq "$program"$'\n'"$filter" "$@"
}

# Prints the text of the modules, each a path without its `.jq`, in that order; fails at the first that cannot be read.
joined_modules() {
  local module text
  for module in "$@"; do
    text="$(<"$module.jq")" || return 1
    printf '%s\n' "$text"
  done
}
