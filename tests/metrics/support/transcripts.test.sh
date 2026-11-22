#!/usr/bin/env bash
# The maker of synthetic transcripts builds the shapes the collector's tests rest on. Each test here keeps one
# property of a shape that such a test would silently pass without.
# shellcheck source=testing.sh
source "$(dirname "${BASH_SOURCE[0]}")/testing.sh"

readonly EPOCH=2026-01-05T09:00:00Z
readonly FIRST_SESSION=dddddddd-0000-4000-8000-000000000001
readonly FORKED_SESSION=dddddddd-0000-4000-8000-000000000002
readonly RESUMED_SESSION=dddddddd-0000-4000-8000-000000000003
# The keys of a record or a `.meta.json` whose values are ids, times, fixed words, model names or numbers. The
# value of any other key is free text.
readonly STRUCTURAL_KEYS='["type", "subtype", "uuid", "sessionId", "agentId", "timestamp", "cwd", "requestId", "id",
  "role", "model", "trigger", "agentType"]'

# Builds a shape of the fixtures into ./<shape>, as its files stand at the minute (default: when all is written).
build() {
  local shape=$1
  shift
  "$SUPPORT/make-transcripts.sh" "$FIXTURES/transcripts/$shape.json" "$PWD/$shape" "$EPOCH" "$@"
}

# catches: a call written as one record, or with its whole output in every record: a collector that adds up
# records, or reads a call's first record, would then pass its token test.
test_an_api_call_spans_several_records_and_only_the_last_holds_its_whole_output() {
  build finished-run
  local run=finished-run/aaaaaaaa-0000-4000-8000-000000000001/subagents/agent-a0000000000000001.jsonl
  assert_equal "$(jq -s -c 'map(select(.type == "assistant")) | length' "$run")" 6
  assert_equal "$(message_ids "$run" | jq length)" 3
  assert_equal "$(outputs_of_call msg_synthetic_run_01 "$run")" '[1,1,100]'
}

# catches: a forked or resumed session that no longer repeats the earlier session's records and runs under the
# same ids: the collector's count-once tests would then pass without counting anything once.
test_a_forked_and_a_resumed_session_repeat_the_records_and_runs_they_copy() {
  build forked-session
  local copied_run=subagents/agent-d0000000000000001
  assert_equal "$(message_ids "forked-session/$FORKED_SESSION.jsonl")" \
    '["msg_synthetic_first_01","msg_synthetic_first_02","msg_synthetic_second_01"]'
  assert_equal "$(message_ids "forked-session/$RESUMED_SESSION.jsonl")" \
    '["msg_synthetic_first_01","msg_synthetic_first_02","msg_synthetic_second_01","msg_synthetic_third_01"]'
  assert_equal "$(compaction_uuids forked-session/*.jsonl)" '["00000000-0000-4000-8000-000000000200"]'
  assert_equal "$(<"forked-session/$RESUMED_SESSION/$copied_run.jsonl")" \
    "$(<"forked-session/$FIRST_SESSION/$copied_run.jsonl")"
  assert_equal "$(<"forked-session/$RESUMED_SESSION/$copied_run.meta.json")" \
    "$(<"forked-session/$FIRST_SESSION/$copied_run.meta.json")"
}

# Prints the output tokens each record of the call holds, in the order of the file.
outputs_of_call() {
  local call=$1 transcript=$2
  jq -s -c --arg call "$call" 'map(select(.message.id == $call) | .message.usage.output_tokens)' "$transcript"
}

# Prints the message ids of the transcripts, each once.
message_ids() {
  jq -s -c 'map(.message.id // empty) | unique' "$@"
}

compaction_uuids() {
  jq -s -c 'map(select(.subtype == "compact_boundary") | .uuid) | unique' "$@"
}

# catches: a later build that changes what an earlier build wrote. A real transcript only grows, so a collector's
# second run must find the records of its first run unchanged, and a run finished since then.
test_a_build_at_a_later_minute_only_adds_to_the_files_of_an_earlier_one() {
  local file late_run=cccccccc-0000-4000-8000-000000000001/subagents/agent-c0000000000000002
  build unfinished-and-unnamed-runs 10
  mv unfinished-and-unnamed-runs earlier
  build unfinished-and-unnamed-runs
  for file in earlier/*.jsonl earlier/*/subagents/*.jsonl; do
    assert_starts_with "$(<"unfinished-and-unnamed-runs/${file#earlier/}")" "$(<"$file")"
  done
  assert_equal "$(jq -c 'has("finished")' "earlier/$late_run.meta.json")" false
  assert_equal "$(jq -c '.finished' "unfinished-and-unnamed-runs/$late_run.meta.json")" true
  assert_equal "$(jq -s 'length' "earlier/$late_run.jsonl")" 2
  assert_equal "$(jq -s 'length' "unfinished-and-unnamed-runs/$late_run.jsonl")" 4
}

# catches: a free text without the mark in a shape or in the maker: the collector's search of its output for the
# mark could not see that text get out.
test_every_free_text_of_every_shape_carries_the_mark() {
  local shape name
  for shape in "$FIXTURES"/transcripts/*.json; do
    name="$(basename "$shape" .json)"
    build "$name"
    assert_equal "$name: $(unmarked_texts "$name")" "$name: []"
  done
}

# Prints the string values of a built shape that stand under a key that is not structural and lack the mark.
unmarked_texts() {
  local folder=$1
  shopt -s nullglob
  cat "$folder"/*.jsonl "$folder"/*/subagents/* | jq -c --argjson structural "$STRUCTURAL_KEYS" '
    paths(strings) as $path
    | ($path | map(strings) | last) as $key
    | select($structural | index($key) == null)
    | getpath($path)
    | select(contains("synthetic-text") | not)
  ' | jq -s -c .
}

run_tests
