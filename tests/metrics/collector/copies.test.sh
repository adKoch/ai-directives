#!/usr/bin/env bash
# What copies of sessions and runs do to the lines: each call is counted once, by the record of what the lines
# counted (ctxm/metrics/counted.csv), and none is lost, whichever transcript is deleted or left out and whichever
# session id sorts first. The cases are the ones inspection AD-A5 r2 found (findings 1 and 2).
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

readonly TOKENS=(input_tokens output_tokens cache_read_tokens cache_write_tokens)
# The sessions of three-session-chain.json, whose ids sort A < B < W.
readonly CHAIN_A=12121212-0000-4000-8000-000000000001 CHAIN_B=12121212-0000-4000-8000-000000000002
readonly CHAIN_W=12121212-0000-4000-8000-000000000003
# The two sessions of fork-renaming-copies.json, the fork first.
readonly FORK_SESSIONS=(eeeeeeee-0000-4000-8000-000000000001 eeeeeeee-0000-4000-8000-000000000002)

# catches: a call lost along a chain of copies: the call A made inside the time B's line spans taken for one B's
# line counted, so that once A is closed it lands in no line.
test_a_chain_of_three_sessions_counts_every_call_once() {
  started_project one-setup
  TRANSCRIPTS_EPOCH="$(minutes_ago 157)" transcripts three-session-chain 100
  collected
  # The collector reads the clock: the same files five minutes older leave A quiet for an hour, so closed.
  TRANSCRIPTS_EPOCH="$(minutes_ago 162)" transcripts three-session-chain
  collected
  cp "$METRICS/tasks.csv" second-collection.csv
  collected
  assert_same_content "$METRICS/tasks.csv" second-collection.csv
  assert_prints '1,10,1000,100' line_fields "$CHAIN_W" "${TOKENS[@]}"
  assert_prints '6,60,6000,600' line_fields "$CHAIN_B" "${TOKENS[@]}"
  assert_prints '8,80,8000,800' line_fields "$CHAIN_A" "${TOKENS[@]}"
}

# Builds a started project and the transcripts of the shape in the id order (given, reversed), collects once, and
# keeps the lines and their record in ./first/.
collected_once_in_id_order() {
  rm -rf project transcripts first
  started_project one-setup
  transcripts_in_id_order "$1" "$2"
  collected
  mkdir first
  cp "$METRICS/tasks.csv" "$METRICS/counted.csv" first/
}

# Fails unless the lines and their record are as ./first/ holds them.
assert_nothing_added() {
  assert_same_content "$METRICS/tasks.csv" first/tasks.csv
  assert_same_content "$METRICS/counted.csv" first/counted.csv
}

# catches: a copy that outlives its original counted again: once either transcript of a renamed fork is deleted,
# the next collection writes the calls the two shared a second time, under the session that is left.
test_calls_a_renamed_fork_shares_are_not_counted_again_once_either_transcript_is_deleted() {
  local order session
  for order in given reversed; do
    for session in "${FORK_SESSIONS[@]}"; do
      collected_once_in_id_order "$order" fork-renaming-copies
      rm "transcripts/$session.jsonl"
      collected
      assert_nothing_added
    done
  done
}

# catches: the same through a transcript left out as not readable whole: a broken line acts as a deletion.
test_calls_a_renamed_fork_shares_are_not_counted_again_once_either_transcript_is_unreadable() {
  local order session
  for order in given reversed; do
    for session in "${FORK_SESSIONS[@]}"; do
      collected_once_in_id_order "$order" fork-renaming-copies
      printf 'synthetic-text is not JSON\n' >>"transcripts/$session.jsonl"
      collected
      assert_nothing_added
      assert_prints 'note: transcripts that cannot be read whole, not written: 1' cat stderr
    done
  done
}

# Prints the input tokens of the original's lines and of the fork's in before-start-fork-resumed.json, built in the
# id order: reversed, the two ids trade places.
resumed_tokens() {
  local original=34343434-0000-4000-8000-000000000002 fork=34343434-0000-4000-8000-000000000001
  [[ "$1" == given ]] || { original=$fork; fork=34343434-0000-4000-8000-000000000002; }
  printf 'original %s, fork %s\n' "$(line_fields "$original" input_tokens)" "$(line_fields "$fork" input_tokens)"
}

# catches: a session that ended before the start, then forked with renaming and resumed in place, counted whole or
# without the calls its fork copied, depending on which id sorts first.
test_a_session_that_ended_before_the_start_forked_and_resumed_counts_the_same_in_both_id_orders() {
  local order
  for order in given reversed; do
    rm -rf project transcripts
    started_project one-setup 2026-01-05T09:20:00Z
    transcripts_in_id_order "$order" before-start-fork-resumed
    collected
    assert_prints 'original 8, fork 7' resumed_tokens "$order"
  done
}

# catches: the same with a collection between the fork and the resume: what the fork copied of a session that ended
# before the start written later through the fork or the resumed session in one id order and not in the other.
test_what_a_fork_copied_of_a_session_that_ended_before_the_start_stays_passed_over_in_both_id_orders() {
  local order
  for order in given reversed; do
    rm -rf project transcripts
    started_project one-setup 2026-01-05T09:20:00Z
    transcripts_in_id_order "$order" before-start-fork-resumed 35
    collected
    transcripts_in_id_order "$order" before-start-fork-resumed
    collected
    assert_prints 'original 8, fork 4' resumed_tokens "$order"
  done
}

# catches: a run copied into a fork while it was still running counted once per copy, or written from the copy
# that stopped at the fork.
test_a_run_still_running_at_a_fork_is_one_line_with_all_its_calls() {
  started_project one-setup
  transcripts run-unfinished-at-the-fork 35
  collected
  transcripts run-unfinished-at-the-fork
  collected
  collected
  assert_prints '3,30,3000,300' line_fields i0000000000000001 "${TOKENS[@]}"
  assert_prints 3 line_count
}

run_tests
