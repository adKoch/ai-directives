# shellcheck shell=bash
# What the collector says: the result on stdout, and the error line when a stopped write could not be undone.
# Sourced by collect-metrics.sh; needs METRICS_FOLDER, TASKS_FILE (store.sh) and plan_part (collect-metrics.sh).

# Prints what a dry run found: the lines it would add, and the roll-ups it would write when there are any.
tell_planned() {
  local count
  count="$(plan_part '.rollups | length' "$1")"
  tell "$TASKS_FILE: lines to add: $(plan_part .result "$1"); dry run, nothing written"
  ((count == 0)) || tell "$METRICS_FOLDER: roll-ups to write: $count; dry run, nothing written"
}

# Prints what a collection wrote: the lines it added, and the roll-ups when there are any.
tell_stored() {
  local count
  count="$(plan_part '.rollups | length' "$1")"
  tell "$TASKS_FILE: lines added: $(plan_part .result "$1")"
  ((count == 0)) || tell "$METRICS_FOLDER: roll-ups written: $count"
}

# Prints the result on stdout. The collection is done by then: a closed stdout loses the message, not the work.
tell() {
  trap '' PIPE
  printf '%s\n' "$1" 2>/dev/null || true
}

tell_unrestored() {
  printf 'error: a replaced file of %s could not be put back; its old bytes stay in <file>.old.%s\n' \
    "$METRICS_FOLDER/" "$$" >&2
}
