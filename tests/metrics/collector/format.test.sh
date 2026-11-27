#!/usr/bin/env bash
# docs/metrics-format.md defines the format once; the collector writes it.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

readonly FORMAT_PAGE="$REPO_ROOT/docs/metrics-format.md"

# Prints the names of the first column of the table under a heading of the page, joined by commas.
names_under() {
  jq --raw-input --slurp --raw-output --arg heading "$1" '
    split("\n## ") | map(select(startswith($heading + "\n"))) | first
    | [scan("\n\\| `([^`]+)` \\|")[]] | join(",")
  ' "$FORMAT_PAGE"
}

# catches: a column added, renamed or moved in the collector but not on the page the roll-ups and the comparison
# are written from (or the other way round).
test_the_header_the_collector_writes_is_the_column_list_of_the_format_page() {
  local header
  started_project one-setup
  transcripts finished-run
  collected
  header="$(names_under Columns)"
  assert_prints "$header" head -n 1 "$METRICS/tasks.csv"
}

# Fails when the mark of the shapes' free text stands in what the collector said.
assert_no_text_got_out_of_the_output() {
  [[ "$(<stdout)$(<stderr)" != *synthetic-text* ]] || fail "text of tasks.csv stands in what the collector said"
}

# catches: lines added to a tasks.csv the collector cannot read (another header, a line that is none of the
# format, a payload in it), which would mix two formats or repeat the payload; or the payload printed.
test_a_lines_file_it_cannot_read_is_refused_and_left_byte_for_byte() {
  local header content
  started_project one-setup
  transcripts finished-run
  header="$(names_under Columns)"
  for content in $'task,role\nREQ-900-1A-x,inspector' "$header"$'\nREQ-900-1A-x,inspector' \
    "$header"$'\n=synthetic-text,"x"'; do
    printf '%s\n' "$content" >"$METRICS/tasks.csv"
    cp "$METRICS/tasks.csv" before.csv
    collect
    assert_prints 1 cat status
    assert_same_content "$METRICS/tasks.csv" before.csv
    assert_no_text_got_out_of_the_output
  done
}

# catches: a lines file under an earlier header refused or left under it, or moved to the new header with a line
# dropped or changed, or without `unknown` in the columns the header gained.
test_a_lines_file_under_an_earlier_header_moves_to_the_new_header_keeping_its_lines() {
  local header
  started_project one-setup
  transcripts finished-run
  collected
  cut -d, -f1-17 "$METRICS/tasks.csv" | grep -v ',main,' >old.csv
  cp old.csv "$METRICS/tasks.csv"
  collected
  header="$(names_under Columns)"
  { printf '%s\n' "$header"; tail -n +2 old.csv | sed 's/$/,unknown,unknown/'; } >moved.csv
  assert_starts_with_content "$METRICS/tasks.csv" moved.csv
  assert_prints 'unknown,unknown' line_fields a0000000000000001 blocking nits
  assert_prints 'none,none' line_fields aaaaaaaa-0000-4000-8000-000000000001 blocking nits
}

# catches: a header cut after a number of columns no header of the format ever had taken for an earlier header.
test_a_lines_file_under_a_header_that_never_was_is_refused() {
  started_project one-setup
  transcripts finished-run
  collected
  cut -d, -f1-18 "$METRICS/tasks.csv" >"$METRICS/tasks.csv.cut"
  mv "$METRICS/tasks.csv.cut" "$METRICS/tasks.csv"
  cp "$METRICS/tasks.csv" before.csv
  collect
  assert_prints 1 cat status
  assert_prints 'error: ctxm/metrics/tasks.csv does not start with the header of the format; restore it from git;'\
' nothing was written' cat stderr
  assert_same_content "$METRICS/tasks.csv" before.csv
}

run_tests
