#!/usr/bin/env bash
# Collects a project's metrics: reads Claude Code's transcripts of the project and adds to ctxm/metrics/tasks.csv
# one line per finished agent run and per closed main session, each with its token sums and the setup that did
# the work. The first collection only records where the project's metrics start (ctxm/metrics/start); what ended
# before it is never collected. Main runs it after each merge.
# Usage: collect-metrics.sh [--dry-run] [--project <folder>] [--transcripts <folder>]
#   --dry-run               print what a collection would add (counts only) and write nothing
#   --project <folder>      the project's main checkout (default: the current folder)
#   --transcripts <folder>  where Claude Code keeps the project's sessions (default: its folder for the project
#                           under ~/.claude/projects/)
# It writes only ctxm/metrics/, numbers and checked names only: no prompt, file or report text. A second
# collection adds nothing; an interrupted one writes nothing.
# Prints the result on stdout (how many lines), and on stderr a count for each reason a run or a session was not
# written. Exits 0 when the collection is done (a closed stdout loses only the result), 1 when it is refused or a
# step fails (one `error:` line; nothing written).
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
# shellcheck source=metrics/store.sh
source "$METRICS_SCRIPTS/store.sh"

readonly USAGE='usage: collect-metrics.sh [--dry-run] [--project <folder>] [--transcripts <folder>]'
DRY_RUN=no
PROJECT_FOLDER=.
TRANSCRIPTS_FOLDER=''

main() {
  trap end_collector EXIT
  require_tools
  shopt -s inherit_errexit
  read_arguments "$@"
  forget_inherited_repository
  find_project "$PROJECT_FOLDER"
  refuse_unsafe_store
  find_transcripts
  name_project
  trap 'refuse "the collection was interrupted; ctxm/metrics/ holds no half-written file"' TERM INT HUP
  if has_stored "$START_FILE"; then
    collect
  else
    start_metrics
  fi
}

# Runs when the collector ends, however it ends: an unfinished write is removed, and a step that failed without
# a refusal of its own (a tool that stopped, a full disk) gets the one line a refusal has; both end with 1.
end_collector() {
  local status=$?
  discard_prepared_file
  ((status == 0)) && return
  ((status == REFUSED_STATUS)) \
    || printf 'error: a step of the collection failed, see above; ctxm/metrics/ holds no half-written file\n' >&2
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

# Sets PROJECT_NAME, or ends the collector when the folder's name is no plain name.
name_project() {
  PROJECT_NAME="$(project_name)"
  [[ -n "$PROJECT_NAME" ]] || refuse "the project folder's name is no plain name, so no line can name the project"
  readonly PROJECT_NAME
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

# A later collection: adds the lines of what ended since the start and has no line yet.
collect() {
  local plan refusal
  plan="$(collection_plan)"
  refusal="$(plan_part '.refusal // empty' "$plan")"
  [[ -z "$refusal" ]] || refuse "$refusal; nothing was written"
  plan_part '.notes[] | "note: \(.)"' "$plan" >&2
  if [[ "$DRY_RUN" == yes ]]; then
    tell "$TASKS_FILE: lines to add: $(plan_part .result "$plan"); dry run, nothing written"
  else
    store_added_lines "$plan"
    tell "$TASKS_FILE: lines added: $(plan_part .result "$plan")"
  fi
}

store_added_lines() {
  local plan=$1
  [[ "$(plan_part .added "$plan")" == 0 ]] || store "$TASKS_FILE" "$(plan_part .content "$plan")"
}

# Prints the plan of the collection (lines.jq), from the facts of the project and of its transcripts.
collection_plan() {
  local written=(--arg written '')
  ! has_stored "$TASKS_FILE" || written=(--rawfile written "$PROJECT/$TASKS_FILE")
  # shellcheck disable=SC2016 # $project, $start and $written are jq's
  collection_facts "$TRANSCRIPTS_FOLDER" | metrics_jq "format events report lines" '
    plan({project: $project, now: (now | floor), start: $start, written: $written})
  ' --null-input --compact-output --arg project "$PROJECT_NAME" --arg start "$(stored_start)" "${written[@]}"
}

# Prints every fact the plan is made from, one JSON object per line: the setups, the sessions, the runs.
collection_facts() {
  local folder=$1
  project_setups
  session_facts "$folder"
  run_facts "$folder" " $(written_agents) "
}

# Prints the agent ids of the runs that have their line, on one line. A tasks.csv that cannot be read gives none
# here: the plan refuses it.
written_agents() {
  has_stored "$TASKS_FILE" || return 0
  metrics_jq format '[written_lines[] | select(.role != main_role) | .agent] | join(" ")' \
    --raw-input --slurp --raw-output "$PROJECT/$TASKS_FILE" 2>/dev/null || true
}

# Prints the result on stdout. The collection is done by then: a closed stdout loses the message, not the work.
tell() {
  trap '' PIPE
  printf '%s\n' "$1" 2>/dev/null || true
}

# Prints a part of the plan as text.
plan_part() {
  printf '%s\n' "$2" | jq --raw-output "$1"
}

main "$@"
