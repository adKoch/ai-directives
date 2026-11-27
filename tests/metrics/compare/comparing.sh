# shellcheck shell=bash
# What a comparison test sources: rolling.sh, and the steps of a comparison scenario. A test builds projects whose
# roll-ups the collector wrote, each in a folder of its own, compares them as a person would, and reads what was
# printed:
#   rolled_up_project alpha one-setup; rolled_up_project beta templates-in-other-order 2026-01-05T09:05:00Z
#   compared alpha/project beta/project
#   assert_prints '| runs | 5 | 4 |' figure_row 'Item REQ-900-1A-first-example' runs
# README.md says how to add a scenario.

# shellcheck source=../rollup/rolling.sh
source "$(dirname "${BASH_SOURCE[0]}")/../rollup/rolling.sh"

readonly COMPARISON="$REPO_ROOT/scripts/compare-setups.sh"
# shellcheck disable=SC2034 # read by the test files
readonly ROLLUP_FILE=ctxm/metrics/REQ-900.md
# What the comparison leaves in the test's folder itself; everything else is the projects', and stays as it was.
readonly COMPARISON_OUTPUT=(stdout stderr status files-before)

# Builds <folder>/project from a history, with its metrics started at the time (default: before the plan), the plan
# and the runs of reviewed-items (rolling.sh), and collects it: the collector writes its roll-up REQ-900.md.
rolled_up_project() {
  local folder=$1 history=$2 start=${3:-}
  mkdir "$folder"
  (
    cd "$folder"
    started_project "$history" "$start"
    commit_plan REQ-900 "$PLAN_TEXT"
    transcripts reviewed-items
    collected
  )
}

# Runs the comparison with the arguments, as the collector runs (an empty environment, the PATH, a home of its own),
# in the UTF-8 locale of a person's terminal, where bash prints a character that turns text around as it is;
# COMPARISON_PATH, when set, is its PATH instead.
# Leaves ./stdout, ./stderr, the exit status in ./status, and the state of the test's folder before the run in
# ./files-before (assert_nothing_written).
compare() {
  local status=0
  mkdir -p home
  files_state >files-before
  in_collector_environment PATH="${COMPARISON_PATH:-$PATH}" LANG=C.UTF-8 "$COMPARISON" "$@" >stdout 2>stderr \
    || status=$?
  printf '%s\n' "$status" >status
}

# Runs the comparison and fails unless it printed one.
compared() {
  compare "$@"
  assert_prints 0 cat status
}

# Runs the comparison with stdout a pipe whose reader has gone: ./stderr and ./status as compare leaves them.
compare_into_a_closed_pipe() {
  local status=0
  : >stdout
  in_collector_environment "$COMPARISON" "$@" 2>stderr | true || status=${PIPESTATUS[0]}
  printf '%s\n' "$status" >status
}

# Prints the row of the figure in the section under the heading (`Plan <plan>`, `Item <task>`, `Setups`) of what
# the comparison printed.
figure_row() {
  local heading=$1 figure=$2 line section=''
  while IFS= read -r line; do
    if [[ "$line" == '#'* ]]; then
      section="${line#"${line%%[!#]*}" }"
    elif [[ "$section" == "$heading" && "$line" == "| $figure |"* ]]; then
      printf '%s\n' "$line"
    fi
  done <stdout
}

# Prints every file and folder under the test's folder with its size, inode and times, but the comparison's output:
# a file written, replaced or touched shows.
files_state() (
  local files=() file
  shopt -s globstar dotglob nullglob
  for file in **; do
    [[ " ${COMPARISON_OUTPUT[*]} " == *" $file "* ]] || files+=("$file")
  done
  stat --format='%n %s %i %y %z' -- "${files[@]}"
)

# Fails unless the test's folder is as it was before the last comparison.
assert_nothing_written() {
  local before
  before="$(<files-before)"
  assert_prints "$before" files_state
}
