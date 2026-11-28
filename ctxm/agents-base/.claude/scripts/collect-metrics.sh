#!/usr/bin/env bash
# Collects a project's metrics: reads Claude Code's transcripts of the project and adds to ctxm/metrics/tasks.csv
# one line per finished agent run and per closed main session, each with its token sums and the setup that did
# the work, adds to ctxm/metrics/counted.csv the ids of the API calls and compactions those lines count, so that
# none is counted twice or lost however the transcripts are copied or deleted, and rewrites the roll-up
# (ctxm/metrics/<plan>.md) of each plan of ctxm/plans/ that has lines. The first collection only records where the
# project's metrics start (ctxm/metrics/start); what ended before it is never collected. Main runs it after each
# merge.
# Usage: collect-metrics.sh [--dry-run] [--project <folder>] [--transcripts <folder>]
#   --dry-run               print what a collection would add (counts only) and write nothing
#   --project <folder>      the project's main checkout (default: the current folder)
#   --transcripts <folder>  where Claude Code keeps the project's sessions (default: its folder for the project
#                           under ~/.claude/projects/)
# It writes only ctxm/metrics/, numbers, checked ids and checked names only: no prompt, file, plan or report text.
# A second collection adds nothing and rewrites the same roll-ups; an interrupted one writes nothing.
# Prints the result on stdout (how many lines, how many roll-ups), and on stderr a count for each reason a run or a
# session was not written. Exits 0 when the collection is done (a closed stdout loses only the result), 1 when it
# is refused, interrupted before its last rename or a step fails (one `error:` line; nothing written, unless a
# replaced file could not be put back: the line says which and where its old bytes are).
# Needs the tools metrics/tools.sh names, from the project's own toolchain, and checks for them first.
# The format and the rules: docs/metrics-format.md of the template library.
set -euo pipefail

case "${BASH_SOURCE[0]}" in
  */*) readonly METRICS_SCRIPTS="${BASH_SOURCE[0]%/*}/metrics" ;;
  *) readonly METRICS_SCRIPTS=metrics ;;
esac
# shellcheck source=metrics/tools.sh
source "$METRICS_SCRIPTS/tools.sh"
# shellcheck source=metrics/program.sh
source "$METRICS_SCRIPTS/program.sh"
# shellcheck source=metrics/project.sh
source "$METRICS_SCRIPTS/project.sh"
# shellcheck source=metrics/transcripts.sh
source "$METRICS_SCRIPTS/transcripts.sh"
# shellcheck source=metrics/plans.sh
source "$METRICS_SCRIPTS/plans.sh"
# shellcheck source=metrics/store.sh
source "$METRICS_SCRIPTS/store.sh"
# shellcheck source=metrics/places.sh
source "$METRICS_SCRIPTS/places.sh"
# shellcheck source=metrics/leftovers.sh
source "$METRICS_SCRIPTS/leftovers.sh"
# shellcheck source=metrics/telling.sh
source "$METRICS_SCRIPTS/telling.sh"

# The rules of a collection, each after the ones it needs (program.sh).
readonly PLAN_MODULES="format setup counted events report holdings rollup rollup_text lines"
readonly USAGE='usage: collect-metrics.sh [--dry-run] [--project <folder>] [--transcripts <folder>]'
DRY_RUN=no
PROJECT_FOLDER=.
TRANSCRIPTS_FOLDER=''

main() {
  trap end_collector EXIT
  trap 'exit "$INTERRUPTED_STATUS"' TERM INT HUP
  require_tools
  shopt -s inherit_errexit
  read_arguments "$@"
  forget_inherited_repository
  find_project "$PROJECT_FOLDER"
  refuse_unsafe_store
  refuse_oversized_files
  refuse_unsettled_files
  refuse_linked_sources
  find_transcripts
  name_project
  if has_stored "$START_FILE"; then
    collect
  else
    start_metrics
  fi
}

# Runs when the collector ends, however it ends: a write that did not reach its end is undone, with no further
# signal stopping that, and the end gets its one `error:` line (a refusal has printed its own); all end with 1.
end_collector() {
  local status=$?
  trap '' TERM INT HUP
  restore_renamed_files
  discard_written_files
  ((status == 0)) && return
  tell_stop "$status"
  exit 1
}

# Sets TRANSCRIPTS_FOLDER, or ends the collector: the folder must be there and hold no link on the way to a
# transcript. The first collection checks it too, so a project it starts can be collected.
find_transcripts() {
  TRANSCRIPTS_FOLDER="${TRANSCRIPTS_FOLDER:-$(default_transcripts_folder)}"
  [[ -d "$TRANSCRIPTS_FOLDER" ]] || refuse "no transcripts folder where it was looked for; name it with --transcripts"
  refuse_linked_transcripts "$TRANSCRIPTS_FOLDER"
  readonly TRANSCRIPTS_FOLDER
}

read_arguments() {
  while (($# > 0)); do
    case "$1" in
      --dry-run) DRY_RUN=yes ;;
      --project) (($# > 1)) || refuse "$USAGE"; PROJECT_FOLDER=$2; shift ;;
      --transcripts) (($# > 1)) || refuse "$USAGE"; TRANSCRIPTS_FOLDER=$2; shift ;;
      *) refuse "$USAGE" ;;
    esac
    shift
  done
}

# The first collection: records where the project's metrics start, and collects nothing.
start_metrics() {
  local now
  now="$(metrics_jq format 'now | floor | time_text' --null-input --raw-output)"
  if [[ "$DRY_RUN" == yes ]]; then
    tell "$START_FILE: the metrics of the project would start now; dry run, nothing written"
  else
    store "$START_FILE" "$now"
    tell "$START_FILE: the metrics of the project start at $now; what ended before is never collected"
  fi
}

# A later collection: adds the lines of what ended since the start and has no line yet, and rewrites the roll-up
# of each plan of ctxm/plans/ that has lines.
collect() {
  local plan refusal
  refuse_lone_empty_lines_file
  plan="$(collection_plan)"
  refusal="$(plan_part '.refusal // empty' "$plan")"
  [[ -z "$refusal" ]] || refuse "$refusal; nothing was written"
  plan_part '.notes[] | "note: \(.)"' "$plan" >&2
  if [[ "$DRY_RUN" == yes ]]; then
    tell_planned "$plan"
  else
    store_collection "$plan"
    tell_stored "$plan"
  fi
}

# Writes the added lines, their record and the roll-ups together, all or nothing (store.sh): every place is checked
# and every file prepared before the first is renamed, and a stop before the last rename puts the old files back.
# Whether the collector may write is checked only when the collection writes something (plan_writes_something).
# tasks.csv is renamed last, just after its record: a kill that cuts the renames off (no trap runs) leaves it old,
# and its record new: the old files the kill left stop every collection until a person moves them back (store.sh).
store_collection() {
  local plan=$1 count index name
  count="$(plan_part '.rollups | length' "$plan")"
  for ((index = 0; index < count; index++)); do
    refuse_unsafe_rollup "$(plan_part ".rollups[$index].plan" "$plan")"
  done
  ! plan_writes_something "$plan" || begin_write
  for ((index = 0; index < count; index++)); do
    name="$(plan_part ".rollups[$index].plan" "$plan")"
    prepare_file "$METRICS_FOLDER/$name.md" "$(plan_part ".rollups[$index].content" "$plan")"
  done
  if [[ "$(plan_part '.counted != null' "$plan")" == true ]]; then
    prepare_file "$COUNTED_FILE" "$(plan_part .counted "$plan")"
    prepare_file "$TASKS_FILE" "$(plan_part .content "$plan")"
  fi
  publish_prepared
}

# Succeeds when the collection writes something: a line, a record or a roll-up to prepare, or a file a killed
# collector left to remove. Only such a collection needs a folder it may write in.
plan_writes_something() {
  [[ "$(plan_part '(.rollups | length) > 0 or .counted != null' "$1")" == true ]] || has_abandoned_files
}

# Prints the plan of the collection (lines.jq), from the facts of the project and of its transcripts, and what
# tasks.csv and its record hold (empty when a file is not there).
collection_plan() {
  local written=(--arg written '') counted=(--arg counted '')
  ! has_stored "$TASKS_FILE" || written=(--rawfile written "$PROJECT/$TASKS_FILE")
  ! has_stored "$COUNTED_FILE" || counted=(--rawfile counted "$PROJECT/$COUNTED_FILE")
  # shellcheck disable=SC2016 # $project, $start, $written and $counted are jq's
  collection_facts "$TRANSCRIPTS_FOLDER" | metrics_jq "$PLAN_MODULES" '
    plan({project: $project, now: (now | floor), start: $start, written: $written, counted: $counted})
  ' --null-input --compact-output --arg project "$PROJECT_NAME" --arg start "$(stored_start)" "${written[@]}" \
    "${counted[@]}"
}

# Prints every fact the plan is made from, one JSON object per line: the setups, the sessions, the runs, and what
# the roll-ups read (plans.sh).
collection_facts() {
  local folder=$1
  project_setups
  session_facts "$folder"
  run_facts "$folder" " $(written_agents) "
  rollup_facts
}

# Prints the agent ids of the runs that have their line, on one line. A tasks.csv that cannot be read gives none
# here: the plan refuses it.
written_agents() {
  has_stored "$TASKS_FILE" || return 0
  metrics_jq format '[written_lines[] | select(.role != main_role) | .agent] | join(" ")' \
    --raw-input --slurp --raw-output "$PROJECT/$TASKS_FILE" 2>/dev/null || true
}

# Prints a part of the plan as text.
plan_part() {
  printf '%s\n' "$2" | jq --raw-output "$1"
}

main "$@"
