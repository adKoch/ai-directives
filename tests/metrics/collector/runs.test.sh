#!/usr/bin/env bash
# The collector writes one line per finished agent run: its task, its token sums, each API call once.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

readonly TOKENS=(input_tokens output_tokens cache_read_tokens cache_write_tokens)

# catches: tokens summed over records instead of calls (a call spans several records, so the sums double), a
# call counted by its first record (its output is not whole yet), or the kinds of tokens added together.
test_a_finished_run_is_one_line_with_the_token_sums_of_its_calls() {
  started_project one-setup
  transcripts finished-run
  collected
  assert_prints 'REQ-900-1A-first-example,inspector,60,600,60000,6000' \
    line_fields a0000000000000001 task role "${TOKENS[@]}"
  assert_prints '2026-01-05T09:02:00Z,2026-01-05T09:11:00Z,540,claude-synthetic-small,medium' \
    line_fields a0000000000000001 start end wall_seconds model effort
  assert_prints 'ctxm/metrics/tasks.csv: lines added: 2 (of runs: 1, of main sessions: 1)' cat stdout
}

# catches: a second collection that writes a run or a session's calls again.
test_a_second_collection_adds_nothing() {
  started_project one-setup
  transcripts forked-session
  collected
  cp "$METRICS/tasks.csv" first-collection.csv
  collected
  assert_same_content "$METRICS/tasks.csv" first-collection.csv
  assert_prints 'ctxm/metrics/tasks.csv: lines added: 0 (of runs: 0, of main sessions: 0)' cat stdout
}

# catches: a run written while it still runs, with the sums of a part of it; or a run that is never written
# because a collection saw it unfinished.
test_an_unfinished_run_is_written_by_the_collection_after_it_finished() {
  started_project one-setup
  transcripts unfinished-and-unnamed-runs 10
  collected
  assert_prints '' line_fields c0000000000000002 task
  transcripts unfinished-and-unnamed-runs
  collected
  assert_prints 'REQ-900-3B-finished-late,2,20,2000,200' line_fields c0000000000000002 task "${TOKENS[@]}"
  assert_prints '' line_fields c0000000000000003 task
}

# catches: a run written under a guessed or empty task name; a task name taken from the first id in the prompt
# instead of the one after `Task:`; a run left out without a word.
test_a_run_whose_prompt_names_no_task_is_counted_and_not_written() {
  started_project one-setup
  transcripts unfinished-and-unnamed-runs
  collected
  assert_prints '' line_fields c0000000000000004 task
  assert_prints 'REQ-900-3E-named-later' line_fields c0000000000000005 task
  assert_prints 'note: runs not finished yet, written once they are: 1
note: finished runs whose first prompt names no task after Task:, not written: 1' cat stderr
}

# catches: a task name taken from a later `Task:` when the first one names none: a run written under a task
# the prompt only mentions.
test_a_run_whose_first_task_names_none_is_not_written_under_a_later_one() {
  started_project one-setup
  transcripts task-name-after-the-first-task
  collected
  assert_prints 'ctxm/metrics/tasks.csv: lines added: 0 (of runs: 0, of main sessions: 0)' cat stdout
  assert_prints 'note: finished runs whose first prompt names no task after Task:, not written: 1' cat stderr
}

# catches: usage from before a compaction dropped, or a compaction not counted.
test_a_compacted_run_keeps_its_earlier_usage_and_counts_its_compactions() {
  started_project one-setup
  transcripts compacted-session
  collected
  assert_prints '3,30,3000,300,1' line_fields b0000000000000001 "${TOKENS[@]}" compactions
  assert_prints '10,100,10000,1000,2' line_fields bbbbbbbb-0000-4000-8000-000000000001 "${TOKENS[@]}" compactions
}

# catches: a run counted once per session folder that holds a copy of it.
test_a_run_copied_into_the_folders_of_forked_sessions_is_one_line() {
  started_project one-setup
  transcripts forked-session
  collected
  assert_prints 'REQ-900-4A-before-the-fork,3,30,3000,300' line_fields d0000000000000001 task "${TOKENS[@]}"
  assert_prints 'REQ-900-4B-after-the-fork,3,30,3000,300' line_fields d0000000000000002 task "${TOKENS[@]}"
  assert_prints 5 line_count
}

# catches: a line under the setup of the collection's day instead of the one in force when the run started: a
# run from before a `ctxm update` would carry the templates and the effort of after it.
test_a_run_carries_the_setup_in_force_when_it_started() {
  local before='agents-base@1111111111111111111111111111111111111111+coding@1111111111111111111111111111111111111111'
  local after='agents-base@2222222222222222222222222222222222222222+coding@2222222222222222222222222222222222222222'
  started_project template-update
  transcripts session-across-template-update
  collected
  assert_prints "medium,project,$before,inspector=claude-synthetic-small/medium+reviewer=claude-synthetic-large/high" \
    line_fields f0000000000000001 effort project templates roles
  assert_prints "high,$after+release-planning@2222222222222222222222222222222222222222" \
    line_fields f0000000000000002 effort templates
}

# catches: a run from before the project was on the templates written under a setup it never had, or left out
# without a word.
test_a_run_at_a_commit_without_the_lock_is_counted_and_not_written() {
  started_project templates-applied-later
  transcripts session-across-template-update
  collected
  assert_prints '' line_fields f0000000000000001 task
  assert_prints 'REQ-900-5B-after-the-update' line_fields f0000000000000002 task
  assert_prints 'note: runs and parts of main sessions at a commit without .ctxm/, not written: 2' cat stderr
}

# catches: one agent file the collector cannot read stopping every later collection while its runs' transcripts
# last, though a later commit fixed it: the runs and sessions after the fix would never be written.
test_what_ran_under_a_setup_a_later_commit_fixed_is_counted_and_the_rest_written() {
  started_project effort-fixed-later
  transcripts session-across-template-update
  collected
  assert_prints '' line_fields f0000000000000001 task
  assert_prints 'REQ-900-5B-after-the-update,high' line_fields f0000000000000002 task effort
  assert_prints '12,120,12000,1200' line_fields ffffffff-0000-4000-8000-000000000001 "${TOKENS[@]}"
  assert_prints "note: runs and parts of main sessions under a setup the collector cannot read that a later commit\
 fixed, never written: 2" cat stderr
}

# catches: a setup the collector cannot read let through because an earlier commit of the project was fine: only a
# later commit fixes it, and until then the collection is refused.
test_a_setup_the_collector_cannot_read_after_a_fine_one_is_still_refused() {
  local commit
  started_project effort-broken-later
  transcripts session-across-template-update
  commit="$(git -C project rev-parse HEAD)"
  collect
  assert_prints 1 cat status
  assert_prints "error: the setup at commit $commit: an agent file of .claude/agents/ names an effort that is no plain\
 word; fix it in a new commit: what ran under this one is then counted on stderr, not written; nothing was written" \
    cat stderr
  assert_prints start ls "$METRICS"
}

run_tests
