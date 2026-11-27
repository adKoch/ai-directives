#!/usr/bin/env bash
# What the comparison refuses before it shows anything: a missing tool, an argument that is no project, a link or a
# file that is no plain one where it reads, a file of ctxm/metrics/ that is no roll-up the collector wrote, a roll-up
# too large. A refusal is one line, exit 1, nothing on stdout and nothing written; a place is printed escaped.
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"

# What the comparison calls, without jq.
readonly TOOLS_WITHOUT_JQ=(bash dirname basename wc timeout)
readonly ROLLUP=alpha/project/$ROLLUP_FILE
readonly NOT_READ='is no roll-up in the format of the collector (docs/metrics-format.md, The roll-ups): collect the'\
' project again with the current templates, or move the file out of the folder'
readonly UNNAMED='is no roll-up: its name is no plan name, and ctxm/metrics/ holds no other .md file; move it out of'\
' the folder'

# Fails unless the last comparison was refused with that line (given in parts, joined by spaces), printed nothing
# on stdout and wrote nothing.
assert_refused() {
  assert_prints 1 cat status
  assert_prints "error: $*" cat stderr
  assert_prints '' cat stdout
  assert_nothing_written
}

# Fails when a raw escape character, or the mark of the synthetic free text, stands in what the comparison said.
assert_nothing_raw_got_out() {
  [[ "$(<stdout)$(<stderr)" != *[$'\e‮\xff']* ]] || fail "a raw control or turning character was printed"
  [[ "$(<stdout)$(<stderr)" != *synthetic-text* ]] || fail "text of a roll-up was printed"
}

# catches: a comparison that reads although a required tool is missing, or whose line no longer names the tool.
test_without_jq_the_comparison_names_it_and_reads_nothing() {
  local tool
  rolled_up_project alpha one-setup
  mkdir tools
  for tool in "${TOOLS_WITHOUT_JQ[@]}"; do
    ln -s "$(command -v "$tool")" "tools/$tool"
  done
  COMPARISON_PATH="$PWD/tools" compare alpha/project
  assert_refused 'scripts/compare-setups.sh needs jq: not on the PATH; README.md (Tools) lists the tools to provide'
}

# catches: a roll-up taken although its text is not what the collector writes: a control character, a link or a
# word in it would be printed, a changed header or figure read as the format, another plan's numbers shown.
test_a_rollup_with_text_the_collector_does_not_write_is_refused_naming_the_file() {
  local original edits index
  rolled_up_project alpha one-setup
  original="$(<"$ROLLUP")"
  edits=(
    '| REQ-900-1B-second-example | 1 |' $'| REQ-900-1B-second-example\e[2J | 1 |'
    '- tests added: unknown' $'- tests added: unknown\n[synthetic-text](https://example.invalid/)'
    '| all | 7 |' '| all | seven |'
    '| all | 7 |' '| all | 07 |'
    '| item | rounds | at the round limit |' '| item | rounds |'
    '| REQ-900-1A-first-example | 2 | no |' '| REQ-900-1A-first-example | 2 | yes |'
    '# Metrics of plan REQ-900' '# Metrics of plan REQ-901'
    '- coverage: whole' '- coverage: whole synthetic-text'
    '- coverage: whole' $'- coverage: whole‮'
  )
  for ((index = 0; index < ${#edits[@]}; index += 2)); do
    printf '%s\n' "${original/"${edits[index]}"/"${edits[index + 1]}"}" >"$ROLLUP"
    compare alpha/project
    assert_refused "$ROLLUP $NOT_READ"
    assert_nothing_raw_got_out
  done
}

# catches: a place from outside printed as it is: a name that holds an escape sequence, a character that turns
# text around or a byte that is no UTF-8 could rewrite the terminal or hide what is shown.
test_places_from_outside_are_printed_escaped_in_a_refusal_and_in_the_comparison() {
  rolled_up_project alpha one-setup
  cp "$ROLLUP" "alpha/project/ctxm/metrics/"$'\e[31m‮\xff.md'
  compare alpha/project
  assert_refused "\$'alpha/project/ctxm/metrics/\\E[31m\\342\\200\\256\\377.md' $UNNAMED"
  assert_nothing_raw_got_out
  rm "alpha/project/ctxm/metrics/"$'\e[31m‮\xff.md'
  mv alpha $'al\e[1m\xffpha'
  compared $'al\e[1m\xffpha/project'
  assert_prints "1" grep --count --fixed-strings "| \$'al\\E[1m\\377pha/project' |" stdout
  assert_nothing_raw_got_out
}

# catches: a roll-up read through a link out of its project, or from a file that is no plain one (a pipe would
# hang the comparison, a folder fail it without its line).
test_a_link_or_a_file_that_is_no_plain_one_where_roll_ups_are_read_is_refused() {
  local metrics=alpha/project/ctxm/metrics
  rolled_up_project alpha one-setup
  mv "$metrics" outside
  ln -s "$PWD/outside" "$metrics"
  compare alpha/project
  assert_refused "$metrics is reached through a symbolic link: the comparison reads only a project's own" \
    "ctxm/metrics/; remove the link"
  rm "$metrics"
  mv outside "$metrics"
  ln -s "$PWD/$ROLLUP" "$metrics/REQ-901.md"
  compare alpha/project
  assert_refused "$metrics/REQ-901.md is no plain file, so no roll-up; move it out of the folder"
  rm "$metrics/REQ-901.md"
  mkfifo "$metrics/REQ-902.md"
  compare alpha/project
  assert_refused "$metrics/REQ-902.md is no plain file, so no roll-up; move it out of the folder"
}

# catches: a file too large for a roll-up, roll-ups too large together, or more of them than a project has, read
# whole: the comparison would take any size of memory and time.
test_too_large_or_too_many_rollups_are_refused_before_one_is_read() {
  local number
  rolled_up_project alpha one-setup
  truncate --size=1048577 alpha/project/ctxm/metrics/REQ-901.md
  compare alpha/project
  assert_refused "alpha/project/ctxm/metrics/REQ-901.md is larger than a roll-up may be (1048576 bytes), so it is" \
    "not read; move it out of the folder"
  for number in {901..917}; do
    truncate --size=1000000 "alpha/project/ctxm/metrics/REQ-$number.md"
  done
  compare alpha/project
  assert_refused "the roll-ups given hold more than 16777216 bytes together; compare fewer projects at once"
  for number in {918..1000}; do
    : >"alpha/project/ctxm/metrics/REQ-$number.md"
  done
  compare alpha/project
  assert_refused "alpha/project/ctxm/metrics holds more than 100 roll-ups"
}

# catches: a folder that holds no metrics compared as if it had none to show, or a comparison of roll-ups that an
# interrupted collection may have left a mix of.
test_a_folder_without_rollups_the_collector_settled_is_refused() {
  mkdir -p no-metrics started/project/ctxm/metrics
  printf '2026-01-01T00:00:00Z\n' >started/project/ctxm/metrics/start
  compare nowhere
  assert_refused 'nowhere is no folder; give the folder of a project'
  compare no-metrics
  assert_refused 'no-metrics has no ctxm/metrics/ folder: its metrics have not started'
  compare started/project
  assert_refused 'started/project/ctxm/metrics holds no roll-up: no plan of the project has lines yet'
  rolled_up_project alpha one-setup
  : >"$ROLLUP.old.4242"
  compare alpha/project
  assert_refused "$ROLLUP.old.4242 is a file an interrupted collection kept, so the roll-ups may be a mix; settle it" \
    "as docs/metrics-format.md (Files) says"
}

# catches: a comparison run without a project or with an option it does not know, or with more projects than it
# shows side by side, instead of the usage line or the limit.
test_no_project_an_unknown_option_or_too_many_projects_is_refused() {
  local usage='usage: compare-setups.sh [--help] [--] <project folder>...; --help says more'
  compare
  assert_refused "$usage"
  compare --project alpha
  assert_refused "$usage"
  compare a b c d e f g h i
  assert_refused 'more than 8 projects given; compare fewer at once'
}

# catches: a comparison into a pipe nobody reads that ends with an error or a broken-pipe line.
test_a_comparison_into_a_closed_pipe_ends_quietly() {
  rolled_up_project alpha one-setup
  compare_into_a_closed_pipe alpha/project
  assert_prints 0 cat status
  assert_prints '' cat stderr
}

run_tests
