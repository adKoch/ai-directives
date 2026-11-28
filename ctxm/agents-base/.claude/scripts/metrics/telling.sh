# shellcheck shell=bash
# What the collector says: the result on stdout, and the error line a collector that stops ends with.
# Sourced by collect-metrics.sh; needs store.sh, tools.sh and plan_part (collect-metrics.sh).

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

# Prints the one `error:` line of a collector that ends with the status, unless a refusal has printed its own: what
# could not be put back comes first, as it needs a person.
tell_stop() {
  if ((${#UNRESTORED_PLACES[@]} > 0)); then
    tell_unrestored
  elif (($1 == INTERRUPTED_STATUS)); then
    printf 'error: the collection was interrupted; ctxm/metrics/ holds no half-written file\n' >&2
  elif (($1 != REFUSED_STATUS)); then
    printf 'error: a step of the collection failed, see above; ctxm/metrics/ holds no half-written file\n' >&2
  fi
}

# Prints each place that could not be put back with where its old bytes are, or that it was not there before. The
# names are the collector's own: a checked plan name or tasks.csv.
unrestored_list() {
  local place items=()
  for place in "${UNRESTORED_PLACES[@]}"; do
    if [[ -e "$(kept_name "$place")" ]]; then
      items+=("${place#"$PROJECT/"} (its old bytes are in ${place##*/}.old.$$)")
    else
      items+=("${place#"$PROJECT/"} (new; remove it, it was not there before)")
    fi
  done
  comma_separated "${items[@]}"
}

# Prints the error line of a stop that could not put back every file. The next collection refuses only while an old
# file is left; a place that was new has none, and its line says what to remove.
tell_unrestored() {
  local advice=''
  ! an_old_file_is_kept || advice="; move each old file over its file; the next collection refuses while one is left"
  printf 'error: the collection stopped and could not put back %s%s\n' "$(unrestored_list)" "$advice" >&2
}

an_old_file_is_kept() {
  local place
  for place in "${UNRESTORED_PLACES[@]}"; do
    [[ ! -e "$(kept_name "$place")" ]] || return 0
  done
  return 1
}
