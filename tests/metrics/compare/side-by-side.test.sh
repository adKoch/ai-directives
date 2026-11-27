#!/usr/bin/env bash
# The comparison of setups: the roll-ups of several projects, a setup to a column, by plan and by item, read
# without a write.
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"

# The runs of reviewed-items end from 09:03 on; a project started at these times leaves the first run out, or every
# run but the final test's.
readonly AFTER_THE_FIRST_RUN=2026-01-05T09:05:00Z
readonly BEFORE_THE_FINAL_TEST=2026-01-05T09:50:00Z

readonly COMMIT=1111111111111111111111111111111111111111
readonly ALPHA_TEMPLATES=agents-base@$COMMIT+coding@$COMMIT BETA_TEMPLATES=coding@$COMMIT+agents-base@$COMMIT
readonly ROLES=inspector=claude-synthetic-small/medium+reviewer=claude-synthetic-large/unknown

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
  assert_prints '| runs | 7 | 6 |' figure_row 'Plan REQ-900' runs
  assert_prints '| defects found at tests | 1 | 1 |' figure_row 'Plan REQ-900' 'defects found at tests'
  assert_prints '| questions brought to the owner | unknown | unknown |' \
    figure_row 'Plan REQ-900' 'questions brought to the owner'
  assert_prints '' cat stderr
  assert_nothing_written
}

# catches: a plan read as whole although the project's metrics start after its first commit, so that what ended
# before the start, and is in no number, looks like work that was never done.
test_a_rollup_whose_metrics_start_after_its_plan_was_first_committed_is_shown_partial() {
  rolled_up_project alpha one-setup
  rolled_up_project beta one-setup "$AFTER_THE_FIRST_RUN"
  compared alpha/project beta/project
  assert_prints '| coverage | whole | partial |' figure_row 'Plan REQ-900' coverage
}

# catches: an item that one setup has no run of shown with zeros, or with another item's figures, in that column.
test_an_item_a_setup_has_no_line_of_reads_none_in_its_column() {
  rolled_up_project alpha one-setup
  rolled_up_project gamma one-setup "$BEFORE_THE_FINAL_TEST"
  compared alpha/project gamma/project
  assert_prints '| runs | 5 | none |' figure_row 'Item REQ-900-1A-first-example' runs
  assert_prints '| runs | 1 | 1 |' figure_row 'Item REQ-900-T1-final-test' runs
  assert_prints '| items | 3 | 1 |' figure_row 'Plan REQ-900' items
}

# catches: a roll-up made under two setups shown under one of them only, so that its numbers pass for that setup's
# alone.
test_a_rollup_made_under_two_setups_is_one_setup_listed_with_each() {
  rolled_up_project delta template-update
  compared delta/project
  assert_prints 2 grep --count '^| 1 | project | delta/project | ' stdout
  assert_prints '| figure | setup 1 |' figure_row 'Plan REQ-900' figure
}

run_tests
