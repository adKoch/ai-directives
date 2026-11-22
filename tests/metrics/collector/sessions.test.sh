#!/usr/bin/env bash
# The collector writes main's own sessions: role `main`, by session id, only the session's own API calls, only
# when the session is closed, and one line per setup and per collection that found new calls.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

readonly TOKENS=(input_tokens output_tokens cache_read_tokens cache_write_tokens)

# catches: a session's line that also counts the calls of its runs (they have their own lines), names a task, or
# guesses an effort the transcript does not give.
test_a_main_session_is_a_line_of_its_own_calls_with_fixed_words_for_what_it_lacks() {
  started_project one-setup
  transcripts finished-run
  collected
  assert_prints 'none,main,none,12,120,12000,1200,claude-synthetic-large,unknown' \
    line_fields aaaaaaaa-0000-4000-8000-000000000001 task role agent "${TOKENS[@]}" model effort
}

# catches: the session that runs the collector written in the middle of its work.
test_a_session_with_a_record_in_the_quiet_period_is_not_written() {
  started_project one-setup
  TRANSCRIPTS_EPOCH="$(minutes_ago 20)" transcripts titled-session
  collected
  assert_prints 'ctxm/metrics/tasks.csv: lines added: 0 (of runs: 0, of main sessions: 0)' cat stdout
  assert_prints 'note: main sessions with a record in the last 60 minutes, written once they are quiet: 1' cat stderr
}

# catches: a resumed session's earlier calls written again, its new calls never written, or its first line
# rewritten: the lines of a session must add up to its transcript, and the file only grows.
test_calls_added_to_a_session_that_has_a_line_give_a_line_for_the_new_calls_only() {
  started_project one-setup
  transcripts compacted-session 20
  collected
  cp "$METRICS/tasks.csv" first-collection.csv
  transcripts compacted-session
  collected
  assert_starts_with_content "$METRICS/tasks.csv" first-collection.csv
  assert_prints '3,30,3000,300,0
7,70,7000,700,2' line_fields bbbbbbbb-0000-4000-8000-000000000001 "${TOKENS[@]}" compactions
}

# catches: a session that goes on across a `ctxm update` written as one line under one of its two setups.
test_a_session_across_a_change_of_setup_is_one_line_per_setup() {
  local before='agents-base@1111111111111111111111111111111111111111+coding@1111111111111111111111111111111111111111'
  local after='agents-base@2222222222222222222222222222222222222222+coding@2222222222222222222222222222222222222222'
  started_project template-update
  transcripts session-across-template-update
  collected
  assert_prints "3,30,3000,300,$before
12,120,12000,1200,$after+release-planning@2222222222222222222222222222222222222222" \
    line_fields ffffffff-0000-4000-8000-000000000001 "${TOKENS[@]}" templates
}

# catches: the calls a forked or resumed session's file copies counted once per file: three files that share
# history would give up to three times the tokens.
test_the_calls_that_forked_sessions_copy_count_once() {
  started_project one-setup
  transcripts forked-session
  collected
  assert_prints '7,70,7000,700,1' line_fields dddddddd-0000-4000-8000-000000000001 "${TOKENS[@]}" compactions
  assert_prints '8,80,8000,800,0' line_fields dddddddd-0000-4000-8000-000000000002 "${TOKENS[@]}" compactions
  assert_prints '16,160,16000,1600,0' line_fields dddddddd-0000-4000-8000-000000000003 "${TOKENS[@]}" compactions
}

# catches: the calls a fork copied passing to the fork once the earlier session's own transcript is deleted
# (Claude Code removes old ones): the next collection would write them a second time, under the fork.
test_calls_a_fork_copied_stay_the_earlier_sessions_when_its_transcript_is_gone() {
  started_project one-setup
  transcripts forked-session
  collected
  cp "$METRICS/tasks.csv" first-collection.csv
  rm transcripts/dddddddd-0000-4000-8000-000000000001.jsonl
  collected
  assert_same_content "$METRICS/tasks.csv" first-collection.csv
}

run_tests
