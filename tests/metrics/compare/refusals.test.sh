#!/usr/bin/env bash
# What the comparison refuses before it shows anything: a missing tool, an argument that is no project, a link or a
# file that is no plain one where it reads, a place it may not read, a file of ctxm/metrics/ that is no roll-up the
# collector wrote, a roll-up too large. A refusal is one line, exit 1, nothing on stdout and nothing written; a place
# is printed escaped.
# shellcheck source=comparing.sh
source "$(dirname "${BASH_SOURCE[0]}")/comparing.sh"

# What the comparison calls, without jq.
readonly TOOLS_WITHOUT_JQ=(bash dirname basename wc timeout sleep)
readonly ROLLUP=alpha/project/$ROLLUP_FILE
readonly NOT_READ='is no roll-up in the format of the collector (docs/metrics-format.md, The roll-ups): collect the'\
' project again with the current templates, or move the file out of the folder'
readonly UNNAMED='is no roll-up: its name is no plan name, and ctxm/metrics/ holds no other .md file; move it out of'\
' the folder'
readonly UNREADABLE='could not be read; let the comparison read it, or move it out of the folder'
# The characters of the abuse cases, made from their bytes when the test runs, so this file holds none of them: an
# escape, the right-to-left override U+202E in UTF-8, and a byte that is no UTF-8.
readonly ESCAPE=$'\033'
TURN_AROUND="$(printf '\342\200\256')"
NO_UTF8="$(printf '\377')"
readonly TURN_AROUND NO_UTF8

# Fails when a raw character of the abuse cases, or the mark of the synthetic free text, stands in what the
# comparison said. Matched byte for byte (the C locale), so the locale of the test's shell cannot change what is found.
assert_nothing_raw_got_out() {
  local LC_ALL=C said character
  said="$(<stdout)$(<stderr)"
  for character in "$ESCAPE" "$TURN_AROUND" "$NO_UTF8"; do
    [[ "$said" != *"$character"* ]] || fail "a raw control or turning character was printed"
  done
  [[ "$said" != *synthetic-text* ]] || fail "text of a roll-up was printed"
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
    '- coverage: whole' "- coverage: whole$TURN_AROUND"
    '- questions brought to the owner: unknown' '- questions brought to the owner: 3'
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
  cp "$ROLLUP" "alpha/project/ctxm/metrics/${ESCAPE}[31m$TURN_AROUND$NO_UTF8.md"
  compare alpha/project
  assert_refused "\$'alpha/project/ctxm/metrics/\\E[31m\\342\\200\\256\\377.md' $UNNAMED"
  assert_nothing_raw_got_out
  rm "alpha/project/ctxm/metrics/${ESCAPE}[31m$TURN_AROUND$NO_UTF8.md"
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

# catches: a project whose ctxm folder is a link out of the project read through it: its ctxm/metrics/ is a plain
# folder there, so only the check of ctxm itself stops it.
test_a_ctxm_folder_that_is_a_link_out_of_the_project_is_refused() {
  rolled_up_project alpha one-setup
  mv alpha/project/ctxm outside
  ln -s "$PWD/outside" alpha/project/ctxm
  compare alpha/project
  assert_refused "alpha/project/ctxm/metrics is reached through a symbolic link: the comparison reads only a" \
    "project's own ctxm/metrics/; remove the link"
}

# catches: a roll-up or a ctxm/metrics/ folder the comparison may not read, refused for another reason or with
# bash's own line beside its own, which prints the place as it is.
test_a_rollup_or_a_metrics_folder_that_cannot_be_read_is_refused_in_one_escaped_line() {
  skip_when_run_as_root
  local metrics=alpha/project/ctxm/metrics locked
  rolled_up_project alpha one-setup
  locked="$metrics/${ESCAPE}[31m${TURN_AROUND}REQ-901.md"
  cp "$ROLLUP" "$locked"
  chmod 000 "$locked"
  compare alpha/project
  assert_refused "\$'$metrics/\\E[31m\\342\\200\\256REQ-901.md' $UNREADABLE"
  assert_nothing_raw_got_out
  rm -f "$locked"
  trap 'chmod u+rwx alpha/project/ctxm/metrics' EXIT
  chmod 000 "$metrics"
  compare alpha/project
  assert_refused "$metrics could not be read; let the comparison read it and list its files"
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
  assert_refused "alpha/project/ctxm/metrics holds more than 100 roll-ups; compare a project with fewer, or move the" \
    "files that are no roll-up of a plan out of the folder"
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

run_tests
