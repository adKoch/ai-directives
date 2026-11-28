#!/usr/bin/env bash
# A project's metrics start at its first collection: what ended before it is never written.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

# Prints whether the start record holds one time between the two given, as the collector writes times.
start_is_between() {
  jq --raw-input --slurp --arg earliest "$1" --arg latest "$2" '
    sub("\n$"; "") | (try fromdateiso8601 catch null) as $start
    | $start != null and $start >= ($earliest | fromdateiso8601) and $start <= ($latest | fromdateiso8601)
  ' "$METRICS/start"
}

# catches: a first collection that back-fills: lines for runs and sessions that ended before the project's
# metrics started.
test_the_first_collection_records_the_start_and_writes_no_line() {
  local before after
  project one-setup
  transcripts finished-run
  before="$(minutes_ago 0)"
  collected
  after="$(minutes_ago 0)"
  assert_prints true start_is_between "$before" "$after"
  assert_prints '?? ctxm/metrics/start' written_files
  collected
  assert_prints '?? ctxm/metrics/start' written_files
  assert_prints 'note: runs and main sessions that ended before the project'"'"'s metrics start, never written: 2' \
    cat stderr
}

# catches: a run or a session that was open at the start cut at the start or left out: it is written whole
# once it has ended (Q-M8); and one that ended before the start written after all.
test_what_ended_before_the_start_is_never_written_and_what_was_open_is_written_whole() {
  started_project one-setup 2026-01-05T09:05:00Z
  transcripts unfinished-and-unnamed-runs
  collected
  assert_prints '' line_fields c0000000000000001 task
  assert_prints '' line_fields cccccccc-0000-4000-8000-000000000001 role
  assert_prints '2026-01-05T09:02:00Z,2,20' line_fields c0000000000000002 start input_tokens output_tokens
}

# catches: a session that spans the start counted only from the start on.
test_a_session_open_across_the_start_is_counted_whole() {
  started_project one-setup 2026-01-05T09:05:00Z
  transcripts finished-run
  collected
  assert_prints '2026-01-05T09:01:00Z,12,120' \
    line_fields aaaaaaaa-0000-4000-8000-000000000001 start input_tokens output_tokens
}

# catches: a back-fill by accident: with the start record and tasks.csv gone, a collection that takes the
# transcripts on disk for new work.
test_after_deleting_the_start_and_the_lines_nothing_that_ended_before_is_written() {
  started_project one-setup
  transcripts finished-run
  collected
  assert_prints 2 line_count
  rm "$METRICS/start" "$METRICS/tasks.csv" "$METRICS/counted.csv"
  collected
  collected
  assert_prints '?? ctxm/metrics/start' written_files
}

# catches: a start record that was lost filled in from the transcripts or the lines: the lines stay, the start
# is now, and nothing older is added.
test_a_lost_start_record_starts_the_metrics_again_and_keeps_the_lines() {
  started_project one-setup
  transcripts finished-run 5
  collected
  rm "$METRICS/start"
  cp "$METRICS/tasks.csv" before.csv
  transcripts finished-run
  collected
  collected
  assert_same_content "$METRICS/tasks.csv" before.csv
}

# catches: a start record that holds anything but one past time taken as a start: a payload read as a time, or
# a time in the future that would keep every run out.
test_a_start_record_with_a_payload_or_a_time_to_come_is_refused() {
  local record
  started_project one-setup
  transcripts finished-run
  for record in $'2026-01-01T00:00:00Z\n=synthetic-text,"x"' '2026-01-01T00:00:00Z,synthetic-text' \
    '2999-01-01T00:00:00Z' '2026-02-31T00:00:00Z'; do
    printf '%s\n' "$record" >"$METRICS/start"
    collect
    assert_prints 1 cat status
    assert_prints 'error: ctxm/metrics/start does not hold one past time such as 2026-01-05T09:00:00Z; restore it'\
' from git; nothing was written' cat stderr
    assert_prints "$record" cat "$METRICS/start"
    assert_prints '?? ctxm/metrics/start' written_files
  done
}

# catches: a start record of any size read whole into the collector and given to jq as an argument: a large one
# would end it with the system's words, a larger one fill its memory.
test_a_start_record_larger_than_one_time_is_refused_before_it_is_read() {
  started_project one-setup
  transcripts finished-run
  printf '2026-01-01T00:00:00Z%065d\n' 0 >"$METRICS/start"
  cp "$METRICS/start" start.before
  collect
  assert_prints 1 cat status
  assert_prints 'error: ctxm/metrics/start is larger than the collector reads (64 bytes); restore it from git;'\
' nothing was written' cat stderr
  assert_same_content "$METRICS/start" start.before
  assert_prints '?? ctxm/metrics/start' written_files
}

# catches: a dry run that starts the metrics, or makes ctxm/metrics/ on the way.
test_a_dry_run_at_the_first_collection_creates_nothing() {
  project one-setup
  transcripts finished-run
  collect_with --dry-run
  assert_prints 0 cat status
  assert_prints 'ctxm/metrics/start: the metrics of the project would start now; dry run, nothing written' cat stdout
  assert_prints '' written_files
}

run_tests
