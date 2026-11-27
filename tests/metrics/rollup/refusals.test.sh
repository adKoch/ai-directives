#!/usr/bin/env bash
# What the roll-ups refuse or leave out: a plan whose name is no plain name, a link where a plan or a roll-up
# stands, a report that is no Findings line, text in a plan. A refusal writes nothing; a leaving-out counts on stderr.
# shellcheck source=rolling.sh
source "$(dirname "${BASH_SOURCE[0]}")/rolling.sh"

readonly LEFT_OUT_PLANS="note: plan files left out: a name, a size or a kind of file that is no plan's"

readonly MALFORMED_FINDINGS='note: runs written without counts: their last line opens with Findings: and is no line'\
' of the format'

# Builds a project that has the plan and the runs of reviewed-items, not yet collected.
project_with_the_plan() {
  started_project one-setup
  commit_plan REQ-900 "$PLAN_TEXT"
  transcripts reviewed-items
}

# Fails unless the last run was refused with that line and ctxm/metrics/ holds only the files named.
assert_refused_leaving() {
  local files=$1
  shift
  assert_prints 1 cat status
  assert_prints "error: $*" cat stderr
  assert_prints "$files" ls "$METRICS"
}

# catches: a plan whose name holds `..`, a space or a leading dot taken for a plan: its roll-up would be named from
# a name that reaches outside ctxm/metrics/ or breaks a table.
test_a_plan_with_a_name_that_is_no_plain_name_is_left_out_and_counted() {
  local name
  project_with_the_plan
  for name in 'a..b' 'my plan' '.hidden' '=cmd' 'x;y'; do
    printf '%s\n' "$PLAN_TEXT" >"project/ctxm/plans/$name.md"
  done
  collected
  assert_prints 'REQ-900.md
start
tasks.csv' ls "$METRICS"
  assert_prints "$LEFT_OUT_PLANS: 4" grep 'plan files' stderr
}

# catches: a plan that is a link read through it: the task names would come from a file outside the project.
test_a_plan_that_is_a_link_is_left_out_and_never_read() {
  project_with_the_plan
  # shellcheck disable=SC2016 # the backticks are the plan's own
  printf '%s\n' '`REQ-900-1A-first-example`' >outside.md
  ln -s "$PWD/outside.md" project/ctxm/plans/REQ-901.md
  collected
  assert_prints 'REQ-900.md
start
tasks.csv' ls "$METRICS"
  assert_prints "$LEFT_OUT_PLANS: 1" grep 'plan files' stderr
}

# catches: a plan folder that is a link read through it, or one that stands where a link was put after the metrics
# started: the plans would come from outside the project.
test_a_plans_folder_that_is_a_link_is_refused_and_nothing_is_written() {
  project_with_the_plan
  mkdir outside
  mv project/ctxm/plans outside/plans
  ln -s "$PWD/outside/plans" project/ctxm/plans
  collect
  assert_refused_leaving start "ctxm/plans is a symbolic link: the collector reads only the project's own files;\
 remove the link; nothing was written"
}

# catches: a roll-up written through a link, or into a folder, that someone put where the roll-up goes.
test_a_rollup_place_that_is_a_link_or_a_folder_is_refused_and_nothing_is_written() {
  project_with_the_plan
  printf 'outside\n' >outside.md
  ln -s "$PWD/outside.md" "$METRICS/REQ-900.md"
  collect
  assert_prints 1 cat status
  assert_prints "error: ctxm/metrics/REQ-900.md is a symbolic link: the collector writes only the project's own\
 ctxm/metrics/; remove the link; nothing was written" cat stderr
  assert_prints outside cat outside.md
  rm "$METRICS/REQ-900.md"
  mkdir "$METRICS/REQ-900.md"
  collect
  assert_refused_leaving 'REQ-900.md
start' "ctxm/metrics/REQ-900.md is no plain file; nothing was written"
  assert_prints '' ls "$METRICS/REQ-900.md"
}

# catches: a roll-up of a plan that does not exist rewritten or removed: the importer of the old releases keeps its
# own files in the same folder.
test_a_roll_up_that_belongs_to_no_plan_is_left_byte_for_byte() {
  project_with_the_plan
  printf 'a roll-up written by another importer\n' >"$METRICS/v0.1.md"
  cp "$METRICS/v0.1.md" before.md
  collected
  assert_same_content "$METRICS/v0.1.md" before.md
  assert_prints 'REQ-900.md
start
tasks.csv
v0.1.md' ls "$METRICS"
}

# catches: a report's text, or a payload after the counts, copied into a line or the roll-up, or a Findings line
# that is no line of the format counted as one.
test_a_findings_line_with_text_or_extra_fields_counts_and_copies_nothing() {
  started_project one-setup
  commit_plan REQ-900 "$PLAN_TEXT"
  transcripts malformed-findings
  collected
  assert_prints 'none,none' line_fields a0000000000000001 blocking nits
  assert_prints 'none,none' line_fields a0000000000000005 blocking nits
  assert_prints "$MALFORMED_FINDINGS: 4" grep 'runs written without counts' stderr
  assert_no_text_got_out
}

# catches: text of a plan (a heading, a formula between backticks, a name that is no task name) in the roll-up.
test_text_in_a_plan_never_reaches_the_rollup() {
  local more
  project_with_the_plan
  # shellcheck disable=SC2016 # the backticks are the plan's own
  more='# synthetic-text heading
**X** (`=HYPERLINK("x")`) `REQ-900-1A-first-example, secret` **Y** (task `../REQ-900-1A-x`)'
  put_file ctxm/plans/REQ-900.md "$PLAN_TEXT"$'\n'"$more"
  commit_all "$PLAN_DATE" "synthetic-text more"
  collected
  assert_no_text_got_out
  assert_prints true jq --raw-input --slurp 'test("HYPERLINK|secret|[.][.]/") | not' "$METRICS/REQ-900.md"
}

# catches: a plan file of any size read before its size is known: a huge file would be slurped into memory.
test_a_plan_over_the_size_limit_is_left_out_unread() {
  project_with_the_plan
  head -c 4300000 /dev/zero | tr '\0' 'a' >project/ctxm/plans/REQ-902.md
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/recording-jq.sh" tools/jq
  PATH="$PWD/tools:$PATH" collect
  assert_prints 0 cat status
  assert_prints 'REQ-900.md
start
tasks.csv' ls "$METRICS"
  assert_prints "$LEFT_OUT_PLANS: 1" grep 'plan files' stderr
  assert_prints 1 grep --count --fixed-strings plans/REQ-900.md tools/jq-files
  assert_prints 0 awk '/REQ-902/ { read++ } END { print read + 0 }' tools/jq-files
}

# catches: a shape of these tests whose free text reaches the roll-up.
test_no_text_of_a_shape_here_reaches_the_rollup() {
  local shape
  for shape in "$SCENARIOS"/shapes/*.json; do
    rm -rf project transcripts
    project_with_the_plan
    transcripts "$(basename "$shape" .json)"
    collected
    assert_no_text_got_out
  done
}

run_tests
