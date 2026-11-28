#!/usr/bin/env bash
# The collector reads no TOML but the lines ctxm writes, and fails closed on any other: a line it skipped could hold
# a template or a key of one, and the fingerprint would name a setup that never ran. Each refusal names the commit and
# the file, echoes nothing of the lock and writes nothing (setup.jq, `read_lock`).
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"
# shellcheck source=locks.sh
source "$(dirname "${BASH_SOURCE[0]}")/locks.sh"

# Collects a format 8 lock whose one template is a commit pin with the line after its entries.
collect_with_template_line() {
  collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'", "extra_lines": '"$(json_lines "$1")"'}]'
}

# catches: a template's only version line in a form TOML reads as a version (indented, a quoted key) or as another
# key (dotted), skipped as no key of the collector's, so a version pin is written as a commit pin.
test_a_key_ctxm_does_not_write_is_refused_and_nothing_is_written() {
  local line
  for line in '  version = "2.1"' $'\tversion = "2.1"' '"version" = "2.1"' "'version' = \"2.1\"" 'version.x = 1' \
    'source.x = 1' 'released = "2.1"'; do
    collect_with_template_line "$line"
    assert_refused_for_the_lock "$UNREAD_LINE"
  done
}

# catches: a template's only version line in a form ctxm never writes (no quotes, a literal string, an escape, a
# comment after it) read as a template without a version: a commit pin, a wrong fingerprint.
test_a_version_line_in_a_form_ctxm_does_not_write_is_refused_and_nothing_is_written() {
  local line
  local backslash=\\
  for line in 'version = 2.1' "version = '2.1'" 'version = "2.1\""' 'version = "2.1\nx"' \
    "version = \"${backslash}u0032.1\"" 'version = "2.1" # note' 'version = """2.1"""'; do
    collect_with_template_line "$line"
    assert_refused_for_the_lock "$UNREAD_LINE"
  done
}

# catches: a key of a template given twice read by its first or its last line, where ctxm refuses the lock.
test_a_key_given_twice_is_refused_and_nothing_is_written() {
  local line
  for line in 'name = "docs"' 'source = "local"' 'version = "2.1"' "commit = \"$COMMIT_TWO\""; do
    collect_with_lock 8 '[{"name": "coding", "version": "2.1", "commit": "'"$COMMIT_ONE"'", "extra_lines": '"$(
      json_lines "$line")"'}]'
    assert_refused_for_the_lock "$UNREAD_LINE"
  done
}

# catches: a template table whose header TOML reads (a comment after it, spaces inside or around it) taken for
# another table, so the template drops out of the fingerprint.
test_a_template_header_ctxm_does_not_write_is_refused_and_nothing_is_written() {
  local header
  for header in '[[templates]] # note' '[[ templates ]]' ' [[templates]]' '[[templates]] ' '[["templates"]]' \
    '[templates]' '[[templates.x]]'; do
    collect_with_lock 8 "$(jq --null-input --compact-output --arg header "$header" --arg commit "$COMMIT_ONE" \
      '[{name: "coding", header: $header, commit: $commit}]')"
    assert_refused_for_the_lock "$UNREAD_LINE"
  done
}

# catches: templates given outside a [[templates]] header (an inline list, a quoted key) or a table header ctxm never
# writes, skipped, so the fingerprint names fewer templates than the lock.
test_a_line_before_the_tables_ctxm_does_not_write_is_refused_and_nothing_is_written() {
  local line
  for line in "templates = [{name = \"docs\", source = \"local\", commit = \"$COMMIT_TWO\"}]" '"templates" = []' \
    'templates.x = 1' '[other]' 'version = 8 # note'; do
    collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]' '{"top_lines": '"$(json_lines "$line")"'}'
    assert_refused_for_the_lock "$UNREAD_LINE"
  done
}

# catches: a lock that gives its format twice read by the last line, where ctxm refuses the lock.
test_a_format_given_twice_is_refused_and_nothing_is_written() {
  collect_with_lock 9 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]' '{"top_lines": ["version = 8"]}'
  assert_refused_for_the_lock "$UNREAD_LINE"
}

# catches: a multi-line string of a table the collector does not read (as ctxm writes one for a value with a line
# break) refused, or a line inside it that reads as a template taken for one: a template that was never applied.
test_a_multi_line_string_in_a_table_not_read_is_skipped_whole() {
  local table opening
  for table in '[values]' '[defaults]' '[[files]]'; do
    for opening in '"""' "'''"; do
      collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]' '{"end_lines": '"$(json_lines "$table" \
        "note = $opening" '[[templates]]' 'name = "docs"' 'source = "local"' "commit = \"$COMMIT_TWO\"" "$opening")"'}'
      assert_prints 0 cat status
      assert_prints "coding@$COMMIT_ONE" line_fields a0000000000000001 templates
    done
  done
}

# catches: a multi-line string opened in the `folders` line taken for a list on one line, so a fake [[templates]]
# table inside it, up to a comment line that closes it, is read as a template that was never applied.
test_a_multi_line_string_in_the_folders_line_is_refused_and_nothing_is_written() {
  collect_with_lock_text "version = 8
folders = [\"\"\"]

[[templates]]
name = \"docs\"
source = \"local\"
commit = \"$COMMIT_TWO\"
# \"\"\"]

[[templates]]
name = \"coding\"
source = \"local\"
commit = \"$COMMIT_ONE\"
"
  assert_refused_for_the_lock "$UNREAD_LINE"
}

# catches: `\"""` in a `"""` string of a table not read taken for its close, so a fake [[templates]] table inside the
# string, up to a comment line that closes it, is read as a template that was never applied.
test_an_escaped_quote_before_three_quotes_closes_no_string() {
  collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]' '{"end_lines": '"$(json_lines '[values]' \
    'x = """a\"""' '[[templates]]' 'name = "docs"' 'source = "local"' "commit = \"$COMMIT_TWO\"" '# """')"'}'
  assert_prints 0 cat status
  assert_prints "coding@$COMMIT_ONE" line_fields a0000000000000001 templates
}

# catches: a multi-line string where ctxm writes none (before the tables, in a template) or one never closed, and a
# one-line string never closed, read past: the lines after it read as headers and keys they are not.
test_a_string_ctxm_does_not_write_is_refused_and_nothing_is_written() {
  local commit_pin='[{"name": "coding", "commit": "'"$COMMIT_ONE"'"}]' more
  for more in '{"end_lines": ["[values]", "note = \"\"\"", "[[templates]]"]}' \
    '{"end_lines": ["[[files]]", "path = '"'''"'a"]}' '{"end_lines": ["[values]", "note = \"a"]}' \
    '{"top_lines": ["note = \"\"\"", "\"\"\""]}'; do
    collect_with_lock 8 "$commit_pin" "$more"
    assert_refused_for_the_lock "$UNREAD_LINE"
  done
  collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'",
    "extra_lines": ["version = \"\"\"", "2.1\"\"\""]}]'
  assert_refused_for_the_lock "$UNREAD_LINE"
}

# catches: the lines ctxm writes around the templates (another table, a blank line, a comment) refused, so no
# collection of a project ctxm set up could be made.
test_the_lines_ctxm_writes_are_read() {
  collect_with_lock 8 '[{"name": "coding", "commit": "'"$COMMIT_ONE"'", "extra_lines": ["", "# a note"]}]' \
    '{"top_lines": ["# a note", "", "[values]", "x = \"[[templates]]\""], "end_lines": ["[[files]]",
      "path = \"a\"", "templates = [\"coding\"]", "merge_type = \"replace\"", "[defaults]", "y = \"1\""]}'
  assert_prints 0 cat status
  assert_prints "coding@$COMMIT_ONE" line_fields a0000000000000001 templates
}

run_tests
