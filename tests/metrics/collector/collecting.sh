# shellcheck shell=bash
# What a collector test sources: testing.sh, and the steps of a collection scenario. A test builds a project and
# its transcripts in its own folder, collects, and reads the lines by column:
#   started_project one-setup; transcripts finished-run; collect
#   assert_prints 'REQ-900-1A-first-example,60' line_fields a0000000000000001 task input_tokens
# The collector is always run as a program, the way main runs it; its stdout, stderr and status land in the
# test's folder. README.md says how to add a scenario.

# shellcheck source=../support/testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/../support/testing.sh"

# shellcheck disable=SC2034 # read by the test files
readonly COLLECTOR="$REPO_ROOT/ctxm/agents-base/.claude/scripts/collect-metrics.sh"
readonly COLLECTOR_TESTS="$REPO_ROOT/tests/metrics/collector"
# Minute 0 of every shape and history, unless a test gives another; long before any test runs.
readonly EPOCH=2026-01-05T09:00:00Z
# shellcheck disable=SC2034 # read by the test files
readonly METRICS=project/ctxm/metrics
readonly TEXT_MARK=synthetic-text

# Prints the file of a shape or a history: one of this folder's own, or one of the fixtures.
scenario_file() {
  local kind=$1 name=$2 own
  case "$kind" in
    shape) own="$COLLECTOR_TESTS/shapes/$name.json" ;;
    history) own="$COLLECTOR_TESTS/histories/$name.json" ;;
  esac
  if [[ -f "$own" ]]; then
    printf '%s\n' "$own"
  elif [[ "$kind" == shape ]]; then
    printf '%s\n' "$FIXTURES/transcripts/$name.json"
  else
    printf '%s\n' "$FIXTURES/projects/$name.json"
  fi
}

# Builds ./project from a history, with minute 0 at the epoch (default: EPOCH). Its metrics have not started.
project() {
  "$SUPPORT/make-project.sh" "$(scenario_file history "$1")" "$PWD/project" "${2:-$EPOCH}"
}

# Builds ./project from a history, with its metrics started at the time (default: days before the epoch), as a
# first collection at that time would have left it.
started_project() {
  project "$1"
  mkdir -p "$METRICS"
  printf '%s\n' "${2:-2026-01-01T00:00:00Z}" >"$METRICS/start"
}

# Builds ./transcripts from a shape, as its files stand at the minute (default: when all is written), with
# minute 0 at TRANSCRIPTS_EPOCH (default: EPOCH).
transcripts() {
  local shape=$1
  shift
  "$SUPPORT/make-transcripts.sh" "$(scenario_file shape "$shape")" "$PWD/transcripts" \
    "${TRANSCRIPTS_EPOCH:-$EPOCH}" "$@"
}

# Runs the collector with the arguments. Leaves ./stdout, ./stderr and the exit status in ./status; a test
# asserts the status, so a refusal is never taken for a collection.
run_collector() {
  local status=0
  "$COLLECTOR" "$@" >stdout 2>stderr || status=$?
  printf '%s\n' "$status" >status
}

# Collects ./project from ./transcripts.
collect() {
  run_collector --project "$PWD/project" --transcripts "$PWD/transcripts"
}

# Collects ./project from ./transcripts with further options of the collector.
collect_with() {
  run_collector --project "$PWD/project" --transcripts "$PWD/transcripts" "$@"
}

# Collects and fails unless the collection was done.
collected() {
  collect
  assert_prints 0 cat status
}

# Prints the named columns of the line of a run (by its agent id) or of each line of a main session (by its
# session id), in the order of the file.
line_fields() {
  local id=$1
  shift
  jq --raw-input --raw-output --null-input --arg id "$id" '
    [inputs | split(",")] | .[0] as $columns | .[1:][]
    | [$columns, .] | transpose | map({key: .[0], value: .[1]}) | from_entries
    | select(.agent == $id or (.role == "main" and .session == $id))
    | [.[$ARGS.positional[]]] | join(",")
  ' "$METRICS/tasks.csv" --args "$@"
}

# Prints how many lines tasks.csv holds, the header not counted.
line_count() {
  jq --raw-input --null-input '[inputs] | length - 1' "$METRICS/tasks.csv"
}

# Prints the time that many minutes before now, as the collector writes times.
minutes_ago() {
  jq --null-input --raw-output --argjson minutes "$1" 'now - $minutes * 60 | floor | todate'
}

# Fails when the mark every free text of a shape carries stands in ctxm/metrics/ or in what the collector said.
assert_no_text_got_out() (
  local file
  shopt -s nullglob dotglob
  for file in "$METRICS"/* stdout stderr; do
    [[ "$(<"$file")" != *"$TEXT_MARK"* ]] || fail "text of a transcript stands in $file"
  done
)

# Prints the project's files that git does not know: all the collector may have written.
written_files() {
  git -C project status --porcelain --untracked-files=all
}
