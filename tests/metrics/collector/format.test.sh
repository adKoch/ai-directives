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

run_tests
