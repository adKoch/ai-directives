# shellcheck shell=bash
# How the collector runs its rules. The rules are jq definitions in the modules beside this file, pure: they read
# their input and their arguments and write nothing. jq 1.8 cannot let one module include another, so the modules
# a filter needs are joined into one program, in the order given: a module comes after the ones it needs.

# Runs jq on a filter that calls the definitions of the named modules; the jq options and files follow.
#   metrics_jq "format facts" 'transcript_facts' --null-input --raw-input <file>
metrics_jq() {
  local modules=$1 filter=$2 module program=''
  shift 2
  for module in $modules; do
    program+="$(<"$METRICS_SCRIPTS/$module.jq")"$'\n'
  done
  jq "$program$filter" "$@"
}
