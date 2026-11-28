#!/usr/bin/env bash
# The collector reads the lock of ctxm 0.7 (format 6), of the 0.8 builds before versions (7) and of ctxm 0.8
# (8, a template pinned to a released version or to a commit), and refuses any other, or a pin that is none, naming
# the commit and the file and writing nothing. The fingerprint's `templates` is `<name>@<commit>` for a commit pin and
# `<name>@<version>@<commit>` for a version pin (docs/metrics-format.md).
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

readonly COMMIT_ONE=1111111111111111111111111111111111111111
readonly COMMIT_TWO=2222222222222222222222222222222222222222
readonly NOTHING_BUT_THE_START='?? ctxm/metrics/start'
readonly NO_PIN="names a template or a library commit that is none"
readonly BAD_PIN="names a template version or a library commit that is none"

# Builds ./project from one commit holding a lock of the given format whose templates are the JSON list.
project_with_lock() {
  local format=$1 templates=$2
  mkdir -p histories
  jq --null-input --argjson format "$format" --argjson templates "$templates" '
    {about: "a lock under test", commits: [{minute: -1440, lock: {version: $format, templates: $templates},
      agents: [{name: "inspector", description: "synthetic-text inspector", model: "claude-synthetic-small",
        effort: "medium"}]}]}
  ' >histories/under-test.json
  SCENARIOS="$PWD" started_project under-test
}

# Fails unless the last collection was refused in one line naming the commit, the lock and the problem, with the
# project holding nothing new but the start record.
assert_refused_for_the_lock() {
  local commit
  commit="$(git -C project rev-parse HEAD)"
  assert_prints 1 cat status
  assert_prints "error: the setup at commit $commit: .ctxm/ctxm.lock $1; fix it in a new commit: what ran under \
this one is then counted on stderr, not written; nothing was written" cat stderr
  assert_prints '' cat stdout
  assert_prints "$NOTHING_BUT_THE_START" written_files
}

# catches: a lock of ctxm 0.7 or of the 0.8 builds before versions refused, or given a version it never had.
test_a_lock_before_format_8_gives_each_template_its_commit_and_no_version() {
  local format
  for format in 6 7; do
    rm -rf project transcripts "$METRICS"
    project_with_lock "$format" '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]'
    transcripts finished-run
    collected
    assert_prints "coding@$COMMIT_ONE" line_fields a0000000000000001 templates
  done
}

# catches: a version pin's version or a commit pin's abbreviated commit left out of the fingerprint, so two setups at
# different versions look the same, or a commit's case making one setup two.
test_a_format_8_lock_names_each_templates_version_and_commit() {
  started_project lock-format-8
  transcripts finished-run
  collected
  assert_prints "agents-base@2.1-a@$COMMIT_ONE+coding@abcdef1+docs@$COMMIT_TWO" \
    line_fields a0000000000000001 templates
}

# catches: the update that rewrites the lock to format 8 putting a session under one setup, or the run before it
# under the setup after it.
test_a_session_across_the_update_to_format_8_is_one_line_per_setup() {
  started_project update-to-format-8
  transcripts session-across-template-update
  collected
  assert_prints "3,30,agents-base@$COMMIT_ONE+coding@$COMMIT_ONE
12,120,agents-base@2.1-a@$COMMIT_TWO+coding@$COMMIT_ONE" \
    line_fields ffffffff-0000-4000-8000-000000000001 input_tokens output_tokens templates
  assert_prints "agents-base@$COMMIT_ONE+coding@$COMMIT_ONE" line_fields f0000000000000001 templates
  assert_prints "agents-base@2.1-a@$COMMIT_TWO+coding@$COMMIT_ONE" line_fields f0000000000000002 templates
}

# catches: a version a person or another tool wrote (a comma, a quote, a formula, a line break, a control character,
# the `@` of the fingerprint) copied into a line of tasks.csv, or read as no version at all (a commit pin).
test_a_version_that_is_none_is_refused_and_nothing_is_written() {
  local version
  for version in '2.1,2' '=1+1' '2.1\nx' '2.1@x' 'v2.1' '2.1-' '2.1..2' '' '1234567.1' '2.1-a b'; do
    rm -rf project transcripts "$METRICS"
    project_with_lock 8 '[{"name": "coding", "version": "'"$version"'", "commit": "'"$COMMIT_ONE"'"}]'
    transcripts finished-run
    collect
    assert_refused_for_the_lock "$BAD_PIN"
  done
}

# catches: a version line that is no well-formed entry (no quotes, a control character, doubled, a comment) read as
# a template without a version: a commit pin, a wrong fingerprint.
test_a_version_line_that_is_malformed_is_refused_and_nothing_is_written() {
  local line
  for line in 'version = 2.1' 'version = "2.1\""' $'version = "2.1\x01"' 'version = "2.1" # note' 'version = "2.1"' 'commit = "abcd"'; do
    rm -rf project transcripts "$METRICS"
    project_with_lock 8 '[{"name": "coding", "version": "2.1", "commit": "'"$COMMIT_ONE"'", "extra_lines": '"$(jq --null-input --arg line "$line" '[$line]')"'}]'
    transcripts finished-run
    collect
    assert_refused_for_the_lock "$NO_PIN"
  done
}

# catches: a commit that is none (a branch, a tag, a short or a long id, a hostile value) accepted.
test_a_commit_that_is_none_is_refused_and_nothing_is_written() {
  local commit
  for commit in main abc "${COMMIT_ONE}0" '=1+1' 'abcd,ef'; do
    rm -rf project transcripts "$METRICS"
    project_with_lock 8 '[{"name": "coding", "commit": "'"$commit"'"}]'
    transcripts finished-run
    collect
    assert_refused_for_the_lock "names a library commit that is none"
  done
}

# catches: a release pinned to an abbreviated commit accepted, which a release never names.
test_a_version_pin_with_an_abbreviated_commit_is_refused_and_nothing_is_written() {
  project_with_lock 8 '[{"name": "coding", "version": "2.1", "commit": "abcdef1"}]'
  transcripts finished-run
  collect
  assert_refused_for_the_lock "$BAD_PIN"
}

# catches: a version in a lock of a format that has none read as a commit pin: the version dropped from the
# fingerprint.
test_a_version_in_a_lock_before_format_8_is_refused_and_nothing_is_written() {
  local format
  for format in 6 7; do
    rm -rf project transcripts "$METRICS"
    project_with_lock "$format" '[{"name": "coding", "version": "2.1", "commit": "'"$COMMIT_ONE"'"}]'
    transcripts finished-run
    collect
    assert_refused_for_the_lock "names a template version in a lock format that has none"
  done
}

run_tests
