#!/usr/bin/env bash
# Transcripts hold everything said in a session; the collector takes numbers, ids and checked names from them
# and nothing else. Each test here sends text where a value is read and expects none of it in ctxm/metrics/ nor
# in what the collector says.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

# Prints every field of the lines and of their record that is not made of the characters a field may hold, as JSON.
fields_outside_the_grammar() {
  jq --raw-input --null-input --compact-output '
    [inputs | split(",")[] | select(test("\\A[A-Za-z0-9][A-Za-z0-9._:@=/+\\[\\]-]*\\z") | not)]
  ' "$METRICS/tasks.csv" "$METRICS/counted.csv"
}

# catches: a prompt, a reply, a description, a title or a compaction notice copied into ctxm/metrics/ or printed.
test_no_text_of_any_shape_reaches_the_metrics_or_the_output() {
  local shape name
  started_project one-setup
  for shape in "$FIXTURES"/transcripts/*.json "$COLLECTOR_TESTS"/shapes/*.json; do
    name="$(basename "$shape" .json)"
    rm -rf transcripts
    transcripts "$name"
    collected
    assert_no_text_got_out
  done
  assert_prints '[]' fields_outside_the_grammar
}

# catches: what stands where the task name is expected taken as the name: a formula, a separator, a quote or a
# line break would break the file's lines or run in a spreadsheet, `..` and `/` would name a path, and a
# secret-like string would be saved and committed.
test_a_payload_where_the_task_name_stands_keeps_the_run_out() {
  started_project one-setup
  transcripts payload-task-names
  collected
  assert_prints 'REQ-900-7Z-valid-name' line_fields 90000000000000009 task
  assert_prints 2 line_count
  assert_prints 'note: finished runs whose first prompt names no task after Task:, not written: 8' \
    cat stderr
  assert_no_text_got_out
  assert_prints '?? ctxm/metrics/counted.csv
?? ctxm/metrics/start
?? ctxm/metrics/tasks.csv' written_files
}

# catches: a message id from a transcript written to the record as it stands: a separator, a quote or a line break
# would break its rows, a leading `=`, `-` or `_` start a spreadsheet formula or no field, and a control character
# or an oversize id would be kept and committed.
test_a_call_id_that_is_no_id_keeps_its_transcript_out_of_the_lines_and_the_record() {
  started_project one-setup
  transcripts payload-call-ids
  collected
  assert_prints 1 line_count
  assert_prints 'line,kind,id
1,call,msg_synthetic_plain_id' cat "$METRICS/counted.csv"
  assert_prints 'note: transcripts that cannot be read whole, not written: 8' cat stderr
  assert_no_text_got_out
}

# catches: a session's title or agent name read at all: the line names the session by its id.
test_payloads_in_a_title_and_an_agent_name_are_never_copied() {
  started_project one-setup
  transcripts payload-title
  collected
  assert_prints 'none,main,99999999-0000-4000-8000-000000000002,none' \
    line_fields 99999999-0000-4000-8000-000000000002 task role session agent
  assert_no_text_got_out
}

# catches: a model or a role from a transcript written as it stands: a control character, a line break after
# the name (which `$` in a pattern lets through) or a comma would break the file's lines.
test_a_role_or_a_model_that_is_no_plain_word_keeps_the_run_out() {
  started_project one-setup
  transcripts unplain-role-and-model
  collected
  assert_prints 'REQ-900-8D-plain-words,inspector,claude-synthetic-small' \
    line_fields 90000000000000004 task role model
  assert_prints 2 line_count
  assert_prints 'note: runs and parts of main sessions with a role or a model that is no plain word, not written: 3' \
    cat stderr
  assert_no_text_got_out
}

# catches: a count written as jq read it (1E+2, 10.0) or beyond what jq holds exactly (1E+30): the roll-ups would
# read a field that is no whole number.
test_a_count_in_another_form_is_written_as_digits_and_one_too_large_keeps_the_run_out() {
  started_project one-setup
  transcripts unplain-counts
  collected
  assert_prints '100,10' line_fields 80000000000000001 input_tokens output_tokens
  assert_prints '' line_fields 80000000000000002 input_tokens
  assert_prints 'note: transcripts that cannot be read whole, not written: 1' cat stderr
}

# Adds a line to a run's transcript: what a damaged or oversize record looks like to the collector.
add_line() {
  printf '%s\n' "$2" >>"transcripts/cccccccc-0000-4000-8000-000000000001/subagents/agent-$1.jsonl"
}

# Prints one JSON record of more than the 8 MiB a line may have.
oversize_record() {
  printf '{"type":"synthetic-text","pad":"%*s"}\n' 8400000 ''
}

# catches: a transcript with a line the collector cannot read written with the sums of its other lines, or
# stopping the whole collection for good: it is left out, counted, and the rest is written.
test_a_run_with_a_malformed_a_truncated_or_an_oversize_line_is_counted_and_not_written() {
  local oversize
  oversize="$(oversize_record)"
  started_project one-setup
  transcripts unfinished-and-unnamed-runs
  add_line c0000000000000001 'synthetic-text is not JSON'
  add_line c0000000000000002 '{"type":"assistant","timestamp":"2026-01-05T09:21:00.000Z","message":{"id":"msg_synth'
  add_line c0000000000000005 "$oversize"
  collected
  assert_prints 1 line_count
  assert_prints 'none,main' line_fields cccccccc-0000-4000-8000-000000000001 task role
  assert_prints 'note: transcripts that cannot be read whole, not written: 3
note: runs not finished yet, written once they are: 1
note: finished runs whose first prompt names no task after Task:, not written: 1' cat stderr
  assert_no_text_got_out
}

run_tests
