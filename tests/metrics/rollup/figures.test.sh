#!/usr/bin/env bash
# A plan's roll-up (ctxm/metrics/<plan>.md): its figures are sums of the lines of tasks.csv and of git, the same
# bytes every time, and a figure with no source says so.
# shellcheck source=rolling.sh
source "$(dirname "${BASH_SOURCE[0]}")/rolling.sh"

readonly ROLLUP=$METRICS/REQ-900.md

# Prints the sum of a column over the lines of the plan's items.
column_sum() {
  jq --raw-input --null-input --arg column "$1" '
    [inputs | split(",")] | .[0] as $columns | .[1:]
    | map([$columns, .] | transpose | map({key: .[0], value: .[1]}) | from_entries)
    | map(select(.task | startswith("REQ-900-")) | .[$column] | tonumber) | add
  ' "$METRICS/tasks.csv"
}

# Prints the row of the roll-up that adds up the plan's items, as the sums of tasks.csv give it.
expected_total_row() {
  local columns=(input_tokens output_tokens cache_read_tokens cache_write_tokens wall_seconds compactions)
  local column row='| all | 7'
  for column in "${columns[@]}"; do
    row+=" | $(column_sum "$column")"
  done
  printf '%s |\n' "$row"
}

# Builds a project with the plan, a commit of its first item, the runs and the session, and collects it.
collect_the_plan() {
  started_project "${1:-one-setup}" "${2:-2026-01-01T00:00:00Z}"
  commit_plan REQ-900 "$PLAN_TEXT"
  put_file src/a.txt "$(printf 'a\nb\nc')"
  commit_all 2026-01-05T09:30:00Z "REQ-900-1A-first-example: change"
  transcripts reviewed-items
  collected
}

# catches: a total that is not the sum of the lines it names (a run counted twice, a kind of token left out), or a
# roll-up that differs from one collection to the next.
test_the_total_of_a_rollup_is_the_sum_of_its_lines_and_a_second_collection_rewrites_the_same_bytes() {
  local total
  collect_the_plan
  total="$(expected_total_row)"
  assert_prints "$total" grep '^| all ' "$ROLLUP"
  cp "$ROLLUP" first.md
  collected
  assert_same_content "$ROLLUP" first.md
  assert_prints 'ctxm/metrics: roll-ups written: 1' tail -n 1 stdout
}

# catches: findings added up without their role, their item or their round, or rounds counted from something but
# the reviews, or the release-tester's blocking findings left out of the escapes.
test_findings_are_counted_by_role_item_and_round_and_the_rounds_follow_the_reviews() {
  collect_the_plan
  assert_prints '| REQ-900-1A-first-example | inspector | 2 | 2 | 4 | 2+0 | 1+3 |' \
    grep 'first-example | inspector' "$ROLLUP"
  assert_prints '| REQ-900-1A-first-example | reviewer | 1 | 1 | 0 | 1 | 0 |' grep 'first-example | reviewer' "$ROLLUP"
  assert_prints '| REQ-900-1A-first-example | 2 | no |' grep '^| REQ-900-1A-first-example | 2 | no' "$ROLLUP"
  assert_prints '| REQ-900-T1-final-test | 0 | no |' grep '^| REQ-900-T1-final-test | 0 | no' "$ROLLUP"
  assert_prints '- defects found at tests (blocking findings of the release-tester): 1' grep 'defects found' "$ROLLUP"
}

# catches: the lines of an item counted from commits that merely mention it, or an item with no commit here (its
# commits may be in another repository) given 0 commits.
test_an_item_has_the_commits_whose_subject_names_it_and_one_with_none_here_has_unknown() {
  collect_the_plan
  assert_prints '| REQ-900-1A-first-example | 1 | 3 | 0 |' grep 'first-example | 1 | 3' "$ROLLUP"
  assert_prints '| REQ-900-1B-second-example | unknown | unknown | unknown |' \
    grep 'second-example | unknown' "$ROLLUP"
}

# catches: a task that a plan only mentions (a dependency, a done list) counted as its item: the runs of another
# plan's item would count in both roll-ups and stretch both periods.
test_a_plans_items_are_only_the_tasks_of_its_item_headings() {
  local other
  # shellcheck disable=SC2016 # the backticks are the plan's own
  other='synthetic-text another plan, after `REQ-900-1A-first-example` and `REQ-900-T1-final-test`.

**2A standard-worker: synthetic-text** (task `REQ-901-2A-never-ran`)'
  started_project one-setup
  commit_plan REQ-900 "$PLAN_TEXT"
  commit_plan REQ-901 "$other"
  transcripts reviewed-items
  collected
  assert_prints 'REQ-900.md
counted.csv
start
tasks.csv' metrics_files
}

# catches: the Findings counts read from the text a run writes after its handback call instead of from the report
# the call delivered, or from an earlier handback instead of the last.
test_a_runs_findings_come_from_its_last_handback_else_from_its_last_text() {
  started_project one-setup
  commit_plan REQ-900 "$PLAN_TEXT"
  transcripts handed-back-reports
  collected
  assert_prints '2,3' line_fields h0000000000000001 blocking nits
  assert_prints 'none,none' line_fields h0000000000000002 blocking nits
  assert_prints '0,4' line_fields h0000000000000003 blocking nits
  assert_no_text_got_out
}

# catches: a number with no source filled in (the stop rule): each of them says `unknown`, none a guess.
test_a_figure_with_no_source_is_unknown_never_a_guess() {
  collect_the_plan
  assert_prints 12 grep -c ': unknown$' "$ROLLUP"
  assert_prints '- exceptions: unknown' grep '^- exceptions' "$ROLLUP"
  assert_prints '- release candidates: unknown' grep 'release candidates' "$ROLLUP"
}

# catches: a roll-up that does not say where the metrics start, so a release whose first part is not in the
# metrics reads as whole.
test_a_plan_first_committed_before_the_start_is_partial_and_after_it_whole() {
  collect_the_plan one-setup 2026-01-04T12:00:00Z
  assert_prints '- coverage: partial' grep '^- coverage' "$ROLLUP"
  assert_prints '- metrics start: 2026-01-04T12:00:00Z' grep '^- metrics start' "$ROLLUP"
  rm -rf project transcripts
  collect_the_plan
  assert_prints '- coverage: whole' grep '^- coverage' "$ROLLUP"
}

# catches: main's cost taken over a period that does not exist: a plan file never committed has no first
# commit, so no period, and main's row is unknown.
test_a_plan_with_no_commit_has_no_period_and_so_no_cost_of_main() {
  started_project one-setup
  mkdir -p project/ctxm/plans
  printf '%s\n' "$PLAN_TEXT" >project/ctxm/plans/REQ-900.md
  transcripts reviewed-items
  collected
  assert_prints '- coverage: unknown' grep '^- coverage' "$ROLLUP"
  assert_prints '- main: unknown' grep '^- main' "$ROLLUP"
}

# catches: main's cost left out of a plan, or taken over a period that cannot be right: one that ends before the
# plan was first committed.
test_main_sessions_that_overlap_the_period_count_whole_and_a_period_ending_before_the_plan_has_none() {
  collect_the_plan
  assert_prints '| 2026-01-04T08:00:00Z | 2026-01-05T09:53:00Z | 1 | 2 | 20 | 2000 | 200 | 5940 | 0 |' \
    grep '^| 2026-01-04' "$ROLLUP"
  rm -rf project transcripts
  started_project one-setup
  put_file ctxm/plans/REQ-900.md "$PLAN_TEXT"
  commit_all 2026-01-06T00:00:00Z "synthetic-text the plan"
  transcripts reviewed-items
  collected
  assert_prints '- main: unknown' grep '^- main' "$ROLLUP"
}

# catches: the order of the applied templates dropped from the fingerprint, so two setups that differ in which
# template wins are compared as one.
test_the_order_the_lock_lists_the_templates_in_is_part_of_the_fingerprint() {
  started_project one-setup
  transcripts finished-run
  collected
  assert_prints 'agents-base@1111111111111111111111111111111111111111+coding@1111111111111111111111111111111111111111' \
    line_fields a0000000000000001 templates
  rm -rf project transcripts
  started_project templates-in-other-order
  transcripts finished-run
  collected
  assert_prints 'coding@1111111111111111111111111111111111111111+agents-base@1111111111111111111111111111111111111111' \
    line_fields a0000000000000001 templates
}

run_tests
