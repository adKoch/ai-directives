#!/usr/bin/env bash
# The comparison of setups: the roll-ups of several projects side by side, a column for each setup and plan, by
# plan and by item, read without a write.
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"

# The runs of reviewed-items end from 09:03 on; a project started at these times leaves the first run out, or every
# run but the final test's.
readonly AFTER_THE_FIRST_RUN=2026-01-05T09:05:00Z
readonly BEFORE_THE_FINAL_TEST=2026-01-05T09:50:00Z

readonly COMMIT=1111111111111111111111111111111111111111
readonly ALPHA_TEMPLATES=agents-base@$COMMIT+coding@$COMMIT BETA_TEMPLATES=coding@$COMMIT+agents-base@$COMMIT
readonly ROLES=inspector=claude-synthetic-small/medium+reviewer=claude-synthetic-large/unknown
# Two release plans of one project, the items of reviewed-items split between them.
# shellcheck disable=SC2016 # the backticks are the plans' own
readonly V09_TEXT='**1A standard-worker: synthetic-text the first** (task `REQ-900-1A-first-example`)

**1B standard-worker: synthetic-text the second** (task `REQ-900-1B-second-example`)'
# shellcheck disable=SC2016 # the backticks are the plan's own
readonly V010_TEXT='**T1 release-tester** (`REQ-900-T1-final-test`)'

# catches: one setup's figures shown in another's column, a figure of the plan taken for an item's, two
# fingerprints that differ only in the order of their templates taken for one setup, or a comparison that writes.
test_two_projects_with_different_fingerprints_are_shown_side_by_side_per_item() {
  rolled_up_project alpha one-setup
  rolled_up_project beta templates-in-other-order "$AFTER_THE_FIRST_RUN"
  compared alpha/project beta/project
  assert_prints "| 1 | project | alpha/project | $ALPHA_TEMPLATES | $ROLES |
| 2 | project | beta/project | $BETA_TEMPLATES | $ROLES |" grep '^| [12] | ' stdout
  assert_prints '| runs | 5 | 4 |' figure_row 'Item REQ-900-1A-first-example' runs
  assert_prints '| rounds | 2 | 2 |' figure_row 'Item REQ-900-1A-first-example' rounds
  assert_prints '| cache read tokens | 1000 | 1000 |' figure_row 'Item REQ-900-1B-second-example' 'cache read tokens'
  assert_prints '| runs | 7 | 6 |' figure_row Plans runs
  assert_prints '| defects found at tests | 1 | 1 |' figure_row Plans 'defects found at tests'
  assert_prints '| questions brought to the owner | unknown | unknown |' \
    figure_row Plans 'questions brought to the owner'
  assert_prints '' cat stderr
  assert_nothing_written
}

# catches: a plan read as whole although the project's metrics start after its first commit, so that what ended
# before the start, and is in no number, looks like work that was never done.
test_a_rollup_whose_metrics_start_after_its_plan_was_first_committed_is_shown_partial() {
  rolled_up_project alpha one-setup
  rolled_up_project beta one-setup "$AFTER_THE_FIRST_RUN"
  compared alpha/project beta/project
  assert_prints '| coverage | whole | partial |' figure_row Plans coverage
}

# catches: an item that one setup has no run of shown with zeros, or with another item's figures, in that column.
test_an_item_a_setup_has_no_line_of_reads_none_in_its_column() {
  rolled_up_project alpha one-setup
  rolled_up_project gamma one-setup "$BEFORE_THE_FINAL_TEST"
  compared alpha/project gamma/project
  assert_prints '| runs | 5 | none |' figure_row 'Item REQ-900-1A-first-example' runs
  assert_prints '| runs | 1 | 1 |' figure_row 'Item REQ-900-T1-final-test' runs
  assert_prints '| items | 3 | 1 |' figure_row Plans items
}

# catches: a roll-up made under two setups shown under one of them only, so that its numbers pass for that setup's
# alone.
test_a_rollup_made_under_two_setups_is_one_setup_listed_with_each() {
  rolled_up_project delta template-update
  compared delta/project
  assert_prints 2 grep --count '^| 1 | project | delta/project | ' stdout
  assert_prints '| figure | setup 1, REQ-900 |' figure_row Plans figure
}

# catches: plans of different names kept apart, so that two projects that ran different plans never stand side by
# side (Q-O17).
test_two_projects_with_different_plan_names_stand_side_by_side() {
  rolled_up_project alpha one-setup
  rolled_up_project_with_plans beta templates-in-other-order "$AFTER_THE_FIRST_RUN" REQ-950 "$PLAN_TEXT"
  compared alpha/project beta/project
  assert_prints '| figure | setup 1, REQ-900 | setup 2, REQ-950 |' figure_row Plans figure
  assert_prints '| runs | 7 | 6 |' figure_row Plans runs
  assert_prints '| runs | 5 | 4 |' figure_row 'Item REQ-900-1A-first-example' runs
}

# catches: the release plans of one project shown apart, or in the order of their names as text (v0.10 before
# v0.9), so that a project's releases never stand side by side in order.
test_the_release_plans_of_one_project_stand_side_by_side_in_release_order() {
  rolled_up_project_with_plans zeta one-setup '' v0.10 "$V010_TEXT" v0.9 "$V09_TEXT"
  compared zeta/project
  assert_prints '| figure | setup 1, v0.9 | setup 1, v0.10 |' figure_row Plans figure
  assert_prints '| items | 2 | 1 |' figure_row Plans items
  assert_prints '| release candidates | 0 | 0 |' figure_row Plans 'release candidates'
}

# catches: an item that only one column has dropped, shown twice, or given another column's figures, instead of
# listed once with `none` in the other columns.
test_items_that_no_other_column_has_are_each_listed_once() {
  rolled_up_project_with_plans zeta one-setup '' v0.9 "$V09_TEXT" v0.10 "$V010_TEXT"
  compared zeta/project
  assert_prints '| runs | 5 | none |' figure_row 'Item REQ-900-1A-first-example' runs
  assert_prints '| runs | 1 | none |' figure_row 'Item REQ-900-1B-second-example' runs
  assert_prints '| runs | none | 1 |' figure_row 'Item REQ-900-T1-final-test' runs
  assert_prints 3 grep --count '^### Item ' stdout
}

# catches: the items listed in the order of their names as text (REQ-900-10A before REQ-900-2A), while the columns read
# numbers as numbers. The rule is run on its own: no plan of the fixtures has a run for such an item.
test_items_are_listed_with_the_numbers_of_their_names_as_numbers() {
  source "$REPO_ROOT/scripts/compare/program.sh"
  # shellcheck disable=SC2016 # jq's own text
  assert_prints '["REQ-900-2A-x","REQ-900-10A-x"]' comparison_jq "$COMPARISON_MODULES" \
    '[{rollup: {items: [{item: "REQ-900-10A-x"}, {item: "REQ-900-2A-x"}]}}] | item_names' --null-input --compact-output
}

# catches: a file named like an old file a collection kept, but of no file the collector writes, taken for one (the
# collector collects such a project, so the comparison must show it); and the collector's own kept file let through.
test_only_an_old_file_of_the_collectors_own_files_stops_the_comparison() {
  local name metrics=alpha/project/ctxm/metrics
  rolled_up_project alpha one-setup
  for name in notes.txt.old.4242 REQ-900.md.old.0 REQ-900.md.old.x4242 .REQ-900.md.old.4242 tasks.csv.new.4242; do
    : >"$metrics/$name"
  done
  compared alpha/project
  assert_prints '| runs | 5 |' figure_row 'Item REQ-900-1A-first-example' runs
  assert_nothing_written
  : >"$metrics/tasks.csv.old.4242"
  : >"$metrics/counted.csv.old.4241"
  compare alpha/project
  assert_refused "$metrics/counted.csv.old.4241 is a file an interrupted collection kept, so the roll-ups may be a" \
    "mix; settle it as docs/metrics-format.md (Files) says"
}

run_tests
