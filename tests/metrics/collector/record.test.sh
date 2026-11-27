#!/usr/bin/env bash
# The record of what the lines counted (ctxm/metrics/counted.csv) is a project file another tool or a person may
# edit. The collector writes it only with tasks.csv, and refuses it, naming the file, whenever it cannot read it or
# it is out of step with tasks.csv: it is never rebuilt from the transcripts, which would count again what the
# copies of a deleted original hold. A refusal is one line, exit 1, nothing written.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

readonly RECORD="$METRICS/counted.csv"
readonly RESTORE_RECORD='restore it from git; nothing was written'

# Builds a project collected once from finished-run: the run's line is line 1, the session's line 2.
collected_project() {
  started_project one-setup
  transcripts finished-run
  collected
}

# Keeps the files of ctxm/metrics/ in ./before/, as they stand before the collection a test refuses.
keep_metrics() {
  rm -rf before
  mkdir before
  cp "$METRICS"/* before/
}

# Fails unless the last collection was refused with that line (given in parts, joined by spaces) and ctxm/metrics/
# holds the files ./before/ holds, byte for byte, and no other.
assert_refused_unchanged() {
  local file
  assert_prints 1 cat status
  assert_prints "error: $*" cat stderr
  for file in before/*; do
    assert_same_content "$METRICS/${file#before/}" "$file"
  done
  metrics_files >after.list
  LC_ALL=C ls before >before.list
  assert_same_content after.list before.list
}

# catches: a tasks.csv whose record is lost read as if no call had been counted, or a record whose tasks.csv is lost
# taken for a new start: the calls the copies hold, or the runs, would be written again.
test_lines_without_their_record_or_a_record_without_its_lines_are_refused() {
  collected_project
  mv "$RECORD" record.csv
  keep_metrics
  collect
  assert_refused_unchanged 'ctxm/metrics/tasks.csv is there without ctxm/metrics/counted.csv, the record of what its' \
    'lines counted; restore both from git; nothing was written'
  mv record.csv "$RECORD"
  mv "$METRICS/tasks.csv" lines.csv
  keep_metrics
  collect
  assert_refused_unchanged 'ctxm/metrics/counted.csv is there without ctxm/metrics/tasks.csv; restore both from git;' \
    'nothing was written'
}

# catches: a write through a link someone put where the record stands: the rows would land outside the project.
test_a_linked_record_or_one_that_is_no_plain_file_is_refused() {
  collected_project
  mkdir outside
  cp "$METRICS/tasks.csv" lines.csv
  rm "$RECORD"
  ln -s "$PWD/outside/counted.csv" "$RECORD"
  transcripts forked-session
  collect
  assert_prints 1 cat status
  assert_prints "error: ctxm/metrics/counted.csv is a symbolic link: the collector writes only the project's own\
 ctxm/metrics/; remove the link; nothing was written" cat stderr
  assert_prints '' ls outside
  rm "$RECORD"
  mkdir "$RECORD"
  collect
  assert_prints 1 cat status
  assert_prints 'error: ctxm/metrics/counted.csv is no plain file; nothing was written' cat stderr
  assert_prints '' ls "$RECORD"
  assert_same_content "$METRICS/tasks.csv" lines.csv
}

# catches: a record with a row the collector cannot read taken as it stands: a payload in a field, a fourth field,
# an id of no id shape or a line that is no line would decide what is counted, or reach the output.
test_a_record_with_a_row_that_is_no_row_of_the_record_is_refused_and_left_byte_for_byte() {
  local row
  collected_project
  cp "$RECORD" whole.csv
  for row in '=synthetic-text,"x"' '2,call,msg_synthetic_extra,synthetic-text' '2,call,"msg_synthetic_quoted"' \
    $'2,call,msg_synthetic_crlf\r' '2,call,=synthetic-text' '0,call,msg_synthetic_zero' '02,call,msg_synthetic_lead' \
    '2,synthetic-text,msg_synthetic_kind' '2,compaction,msg_synthetic_not_a_uuid' ''; do
    { cat whole.csv; printf '%s\n' "$row"; } >"$RECORD"
    keep_metrics
    collect
    assert_refused_unchanged "ctxm/metrics/counted.csv holds a row that is no row of the record; $RESTORE_RECORD"
  done
}

# catches: a record that names one call twice, or opens with another header, read as it stands.
test_a_record_that_names_an_event_twice_or_has_another_header_is_refused() {
  collected_project
  cp "$RECORD" whole.csv
  { cat whole.csv; tail -n 1 whole.csv; } >"$RECORD"
  keep_metrics
  collect
  assert_refused_unchanged "ctxm/metrics/counted.csv names an event twice; $RESTORE_RECORD"
  sed '1s/.*/line,id,kind/' whole.csv >"$RECORD"
  keep_metrics
  collect
  assert_refused_unchanged "ctxm/metrics/counted.csv does not start with the header of the record; $RESTORE_RECORD"
}

# catches: a record out of step with tasks.csv: rows of a line that is not there, or of a run's line, or a main
# session's line without its rows, whose calls would then be counted again.
test_a_record_out_of_step_with_the_lines_is_refused() {
  local record
  collected_project
  cp "$RECORD" whole.csv
  for record in "$(head -n 1 whole.csv)" "$(sed 's/^2,/3,/' whole.csv)" "$(sed 's/^2,/1,/' whole.csv)"; do
    printf '%s\n' "$record" >"$RECORD"
    keep_metrics
    collect
    assert_refused_unchanged 'ctxm/metrics/counted.csv and ctxm/metrics/tasks.csv are out of step: a row names a' \
      "line that is no main session's line of tasks.csv, or a main session's line has no row; restore both from" \
      'git; nothing was written'
  done
}

# catches: a collection stopped between the record's rename and tasks.csv's, the last, or right after the last,
# that leaves the record ahead of the lines.
test_an_interrupt_at_the_last_rename_leaves_the_lines_and_their_record_as_they_were() {
  local mode renames
  for mode in interrupt-before interrupt-after; do
    # The record is renamed first, tasks.csv last; each rename made is undone by one more.
    renames=3
    [[ "$mode" == interrupt-before ]] || renames=4
    rm -rf project transcripts tools
    started_project one-setup
    transcripts finished-run 5
    collected
    keep_metrics
    transcripts finished-run
    mkdir tools
    ln -s "$COLLECTOR_TESTS/standins/stopping-second-mv.sh" tools/mv
    printf '%s\n' "$mode" >tools/mv-stop
    PATH="$PWD/tools:$PATH" collect
    assert_refused_unchanged 'the collection was interrupted; ctxm/metrics/ holds no half-written file'
    assert_prints "$renames" cat tools/mv-calls
  done
}

# catches: the record's new file a killed collector left piling up, or its kept old file removed or written over
# before a person has settled it: they are handled as tasks.csv's are.
test_the_working_files_a_killed_collector_left_of_the_record_are_handled_as_those_of_the_lines() {
  local dead
  collected_project
  sleep 0 &
  dead=$!
  wait "$dead"
  printf 'x\n' >"$RECORD.new.$dead"
  collected
  assert_prints 'counted.csv
start
tasks.csv' metrics_files
  printf 'old bytes\n' >"$RECORD.old.$dead"
  keep_metrics
  collect
  assert_refused_unchanged "ctxm/metrics/ holds 1 old file(s) (<file>.old.<process id>) that a stopped collection" \
    'kept; move each over its file, or remove it once its file is right; nothing was written'
}

run_tests
