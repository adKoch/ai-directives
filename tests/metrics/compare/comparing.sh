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
readonly COMPARISON_OUTPUT=(stdout stderr status files-before checkout-before)
# The comparison's TMPDIR: a folder of the test's own, so a temporary file it left would show in files_state.
readonly TEMPORARY_FOLDER=temporary

# Builds <folder>/project from a history, with its metrics started at the time (default: before the plan), the plan
# REQ-900 and the runs of reviewed-items (rolling.sh), and collects it: the collector writes its roll-up REQ-900.md.
rolled_up_project() {
  rolled_up_project_with_plans "$1" "$2" "${3:-}" REQ-900 "$PLAN_TEXT"
}

# Builds <folder>/project as rolled_up_project does, with the plans given (a name and a text each) instead of REQ-900:
# the collector writes a roll-up for each plan whose items ran.
#   rolled_up_project_with_plans zeta one-setup "" v0.9 "$V09_TEXT" v0.10 "$V010_TEXT"
rolled_up_project_with_plans() {
  local folder=$1 history=$2 start=$3
  shift 3
  mkdir "$folder"
  (
    cd "$folder"
    started_project "$history" "$start"
    while (($# > 0)); do
      commit_plan "$1" "$2"
      shift 2
    done
    transcripts reviewed-items
    collected
  )
}

# Runs the comparison with the arguments, as the collector runs (an empty environment, the PATH, a home of its own),
# in the UTF-8 locale of a person's terminal, where bash prints a character that turns text around as it is;
# COMPARISON_PATH, when set, is its PATH instead.
# Leaves ./stdout, ./stderr, the exit status in ./status, and what assert_nothing_written compares with.
compare() {
  local status=0
  note_what_was_there
  in_comparison_environment "$@" >stdout 2>stderr || status=$?
  printf '%s\n' "$status" >status
}

# Runs the comparison and fails unless it printed one.
compared() {
  compare "$@"
  assert_prints 0 cat status
}

# Fails unless the last comparison was refused with that line (given in parts, joined by spaces), printed nothing
# on stdout and wrote nothing.
assert_refused() {
  assert_prints 1 cat status
  assert_prints "error: $*" cat stderr
  assert_prints '' cat stdout
  assert_nothing_written
}

# Runs the comparison with stdout a pipe whose reader has gone: ./stderr and ./status as compare leaves them.
compare_into_a_closed_pipe() {
  local status=0
  : >stdout
  note_what_was_there
  in_comparison_environment "$@" 2>stderr | true || status=${PIPESTATUS[0]}
  printf '%s\n' "$status" >status
}

# Runs the comparison with stdout a device that takes no byte (/dev/full): ./stderr and ./status as compare leaves
# them, ./stdout empty.
compare_into_a_full_device() {
  local status=0
  : >stdout
  note_what_was_there
  in_comparison_environment "$@" >/dev/full 2>stderr || status=$?
  printf '%s\n' "$status" >status
}

in_comparison_environment() {
  in_collector_environment PATH="${COMPARISON_PATH:-$PATH}" LANG=C.UTF-8 TMPDIR="$PWD/$TEMPORARY_FOLDER" \
    "$COMPARISON" "$@"
}

# Notes the state of the test's folder in ./files-before and of the library checkout in ./checkout-before.
note_what_was_there() {
  mkdir -p home "$TEMPORARY_FOLDER"
  files_state >files-before
  checkout_state >checkout-before
}

# Prints the row of the figure in the section under the heading (`Plans`, `Item <task>`, `Setups`) of what
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

# Prints every file and folder of the library checkout with its size, inode and times, but its git store and the
# cache's test runs and check logs, which the test run itself writes: a cache folder made, or a file written,
# replaced or touched, shows.
checkout_state() (
  local places=(.) place
  cd "$REPO_ROOT"
  shopt -s globstar dotglob nullglob
  for place in * .cache/*; do
    case "$place" in
      .git | .cache/tests | .cache/check) ;;
      .cache) places+=("$place") ;;
      *) places+=("$place" "$place"/**) ;;
    esac
  done
  stat --format='%n %s %i %y %z' -- "${places[@]}"
)

# Fails unless the test's folder, its TMPDIR and the library checkout are as they were before the last comparison.
assert_nothing_written() {
  local before
  before="$(<files-before)"
  assert_prints "$before" files_state
  before="$(<checkout-before)"
  assert_prints "$before" checkout_state
}

# Skips the test that calls it (skip_test) when the tests run as root: root reads a file whatever its mode, so a test
# that locks a file would check nothing.
skip_when_run_as_root() {
  ((EUID != 0)) || skip_test "run as root, which no file mode stops"
}
