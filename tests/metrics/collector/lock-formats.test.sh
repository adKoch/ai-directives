#!/usr/bin/env bash
# The collector reads the lock of ctxm 0.7 (format 6), of the 0.8 builds before versions (7) and of ctxm 0.8
# (8, a template pinned to a released version or to a commit), and refuses any other, or a pin that is none, naming
# the commit and the file and writing nothing. The fingerprint's `templates` is `<name>@<commit>` for a commit pin and
# `<name>@<version>@<commit>` for a version pin (docs/metrics-format.md). A pin is read as ctxm reads it: what ctxm
# refuses is refused, what it reads is read. The lines of a lock the collector does not read: lock-lines.test.sh.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"
# shellcheck source=locks.sh
source "$(dirname "${BASH_SOURCE[0]}")/locks.sh"

# The longest version ctxm reads: 64 characters.
readonly LONGEST_VERSION=1.2-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

# catches: a lock of ctxm 0.7 or of the 0.8 builds before versions refused, or given a version it never had.
test_a_lock_before_format_8_gives_each_template_its_commit_and_no_version() {
  local format
  for format in 6 7; do
    collect_with_lock "$format" '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]'
    assert_prints 0 cat status
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

# catches: a version ctxm reads (a number of any u32 size, a date as a number, a suffix with dots or dashes, the
# longest) refused, so every collection that needs that setup is refused for a lock ctxm wrote.
test_a_version_ctxm_reads_is_read() {
  local version
  for version in 20261128.0 1234567.1 4294967295.0 0.0 2.1.3-rc.1 2.1-lock 2.1-a-b.c "$LONGEST_VERSION"; do
    collect_with_lock 8 '[{"name": "coding", "version": "'"$version"'", "commit": "'"$COMMIT_ONE"'"}]'
    assert_prints 0 cat status
    assert_prints "coding@$version@$COMMIT_ONE" line_fields a0000000000000001 templates
  done
}

# catches: a version a person or another tool wrote (a comma, a formula, the `@` of the fingerprint, a space, a
# control character), or one ctxm refuses (a leading zero, a `.lock` ending in any case, a number past u32, four
# numbers, an empty suffix part, one character too long), copied into tasks.csv or read as a commit pin.
test_a_version_that_is_none_is_refused_and_nothing_is_written() {
  local version
  for version in '2.1,2' '=1+1' '2.1@x' 'v2.1' '2.1-' '2.1..2' '' '2.1-a b' 02.1 2.01 2.1-a.lock \
    2.1-A.LOCK 4294967296.0 2.1.0.1 2.1-a..b "${LONGEST_VERSION}a"; do
    collect_with_lock 8 '[{"name": "coding", "version": "'"$version"'", "commit": "'"$COMMIT_ONE"'"}]'
    assert_refused_for_the_lock "$BAD_PIN"
  done
  collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'", "extra_lines": '"$(
    json_lines $'version = "2.1\x01"')"'}]'
  assert_refused_for_the_lock "$BAD_PIN"
}

# catches: a commit that is none (a branch, a tag, a short or a long id, a sha-256 id, a hostile value) accepted, in a
# lock before format 8 or in format 8.
test_a_commit_that_is_none_is_refused_and_nothing_is_written() {
  local format commit
  for format in 6 8; do
    for commit in main abc "${COMMIT_ONE}0" '=1+1' 'abcd,ef' "${COMMIT_ONE}111111111111111111111111"; do
      collect_with_lock "$format" '[{"name": "coding", "commit": "'"$commit"'"}]'
      assert_refused_for_the_lock "names a library commit that is none"
    done
  done
}

# catches: a lock before format 8 read by the 0.7 rule (40 or 64 lowercase digits), where ctxm 0.8 reads any commit
# pin as 4 to 40 digits in either case: an abbreviated or capital commit refused, and one setup written as two.
test_a_lock_before_format_8_reads_a_commit_as_ctxm_does() {
  collect_with_lock 7 '[{"name": "coding", "commit": "ABCDEF1"}]'
  assert_prints 0 cat status
  assert_prints "coding@abcdef1" line_fields a0000000000000001 templates
}

# catches: a release pinned to an abbreviated commit accepted, which a release never names.
test_a_version_pin_with_an_abbreviated_commit_is_refused_and_nothing_is_written() {
  collect_with_lock 8 '[{"name": "coding", "version": "2.1", "commit": "abcdef1"}]'
  assert_refused_for_the_lock "$BAD_PIN"
}

# catches: a version in a lock of a format that has none read as a commit pin: the version dropped from the
# fingerprint.
test_a_version_in_a_lock_before_format_8_is_refused_and_nothing_is_written() {
  local format
  for format in 6 7; do
    collect_with_lock "$format" '[{"name": "coding", "version": "2.1", "commit": "'"$COMMIT_ONE"'"}]'
    assert_refused_for_the_lock "names a template version in a lock format that has none"
  done
}

# catches: a template without its source, or the same template twice, accepted where ctxm refuses the lock.
test_a_template_ctxm_refuses_is_refused_and_nothing_is_written() {
  collect_with_lock 8 '[{"name": "coding", "source": null, "commit": "'"$COMMIT_ONE"'"}]'
  assert_refused_for_the_lock "names a template without a source"
  collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}, {"name": "coding", "commit": "abcd"}]'
  assert_refused_for_the_lock "names a template twice"
}

# catches: a template name ctxm refuses (a `..`, `.git` or empty part, a closing dot) accepted, or one the fingerprint
# cannot hold (an `_`, the `+` and `@` between its parts) written, so two setups read as one or a line is broken.
test_a_template_name_that_is_none_is_refused_and_nothing_is_written() {
  local name
  for name in a/../b .git/x A/.GIT x. a//b /a; do
    collect_with_lock 8 '[{"name": "'"$name"'", "commit": "'"$COMMIT_ONE"'"}]'
    assert_refused_for_the_lock "names a template or a library commit that is none"
  done
  for name in team/rust_x a+b a@b .hidden; do
    collect_with_lock 8 '[{"name": "'"$name"'", "commit": "'"$COMMIT_ONE"'"}]'
    # shellcheck disable=SC2016 # the backticks are the message's own
    assert_refused_for_the_lock 'names a template the fingerprint cannot hold: only letters, digits, `.`, `-` and `/`'
  done
}

run_tests
