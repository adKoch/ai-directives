#!/usr/bin/env bash
# What the collector does with its own working files and its environment: it ends with one line when a tool of its
# own fails, tells a closed pipe from a refusal, removes what a killed collector left, and reads only its project's
# repository.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

# catches: a jq program that does not compile (status 3) taken for a refusal that already printed its line: the
# collector would end with no `error:` line at all.
test_a_failing_jq_ends_the_collector_with_one_error_line() {
  started_project one-setup
  transcripts finished-run
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/failing-jq.sh" tools/jq
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
  assert_prints 'jq: error: synthetic compile failure
error: a step of the collection failed, see above; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints start ls "$METRICS"
}

# catches: a collection that is done reported as failed, or noisy, when stdout is a pipe nobody reads: a closed
# descriptor and a closed pipe fail differently.
test_a_collection_into_a_closed_pipe_is_done_quietly() {
  started_project one-setup
  transcripts finished-run
  run_collector_into_a_closed_pipe --project "$PWD/project" --transcripts "$PWD/transcripts"
  assert_prints 0 cat status
  assert_prints '' cat stderr
  assert_prints 2 line_count
}

# catches: new files a killed collector left (`<file>.new.<its process id>`) piling up in ctxm/metrics/ for good,
# or a collector that removes the file of another that still runs.
test_the_working_files_of_a_killed_collector_are_removed_and_those_of_a_live_one_kept() {
  local dead alive
  started_project one-setup
  transcripts finished-run
  sleep 0 &
  dead=$!
  wait "$dead"
  sleep 60 &
  alive=$!
  printf 'x\n' >"$METRICS/tasks.csv.new.$dead"
  printf 'x\n' >"$METRICS/start.new.$dead"
  printf 'x\n' >"$METRICS/tasks.csv.new.$alive"
  printf 'x\n' >"$METRICS/notes.new.synthetic"
  collected
  kill "$alive"
  assert_prints "counted.csv
notes.new.synthetic
start
tasks.csv
tasks.csv.new.$alive" metrics_files
}

# catches: foreign files of ctxm/metrics/ named like the collector's working files taken for them: a file of another
# tool removed as an abandoned one, or its name stopping every collection for good, while the collector's own old
# file still stops it.
test_a_file_that_is_none_of_the_collectors_is_neither_removed_nor_a_reason_to_refuse() {
  local dead name
  started_project one-setup
  transcripts finished-run
  sleep 0 &
  dead=$!
  wait "$dead"
  for name in "notes.txt.old.$dead" "notes.txt.new.$dead" "a..md.old.$dead" tasks.csv.old.0; do
    printf 'x\n' >"$METRICS/$name"
  done
  collected
  assert_prints "a..md.old.$dead
counted.csv
notes.txt.new.$dead
notes.txt.old.$dead
start
tasks.csv
tasks.csv.old.0" metrics_files
  printf 'x\n' >"$METRICS/tasks.csv.old.$dead"
  metrics_files >before.list
  cp "$METRICS/tasks.csv" lines.csv
  collect
  assert_prints 1 cat status
  assert_prints "error: ctxm/metrics/ holds 1 old file(s) a stopped collection kept, the first tasks.csv.old.$dead;\
 move each over its file (the name without .old.<process id>), or remove it once its file is right; nothing was\
 written" cat stderr
  metrics_files >after.list
  assert_same_content after.list before.list
  assert_same_content "$METRICS/tasks.csv" lines.csv
}

# Runs the collector with a git that stalls, sends it TERM once git waits, and lets git go; ./status and ./stderr are
# as run_collector leaves them. The collector's process id is noted by the shell that becomes it.
signal_the_collector_while_it_waits_for_git() {
  local waited=0 started status=0
  PATH="$PWD/tools:$PATH" in_collector_environment bash -c 'printf "%s\n" "$$" >collector-pid; exec "$@"' _ "$COLLECTOR" \
    --project "$PWD/project" --transcripts "$PWD/transcripts" >stdout 2>stderr &
  started=$!
  until [[ -s tools/git-stalled ]] || ((++waited > 100)); do sleep 0.1; done
  kill -TERM "$(<collector-pid)"
  kill "$(<tools/git-stalled)"
  wait "$started" || status=$?
  printf '%s\n' "$status" >status
}

# catches: a TERM before the collector has read its project (it waits for git) ended as a failed step with 143 and no
# line saying it was interrupted.
test_a_signal_while_the_collector_looks_at_the_project_ends_it_as_interrupted() {
  started_project one-setup
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/stalling-git.sh" tools/git
  signal_the_collector_while_it_waits_for_git
  assert_prints 1 cat status
  assert_prints 'error: the collection was interrupted; ctxm/metrics/ holds no half-written file' cat stderr
}

# catches: the collector reading a repository named by the caller's environment (a git hook sets GIT_DIR and more)
# instead of the project's own: its lines would carry another project's setups, or none.
test_a_git_environment_of_the_caller_does_not_change_which_repository_is_read() {
  started_project one-setup
  transcripts finished-run
  git init --quiet decoy
  run_collector_with_git_variables
  assert_prints 0 cat status
  assert_prints 2 line_count
  assert_prints '' git -C decoy status --porcelain --untracked-files=all
}

# catches: a metrics folder the collector may not write met with the shell's own line before the error line (a
# place printed as it is), instead of one refusal.
test_a_metrics_folder_the_collector_may_not_write_is_refused_in_one_line() {
  ((EUID != 0)) || skip_test "root may write in a folder without write permission"
  started_project one-setup
  transcripts finished-run
  trap 'chmod u+w project/ctxm/metrics' EXIT
  chmod a-w "$METRICS"
  collect
  assert_prints 1 cat status
  assert_prints 'error: the collector may not write in ctxm/metrics/; let it write there, ctxm/metrics/ is its only'\
' place; nothing was written' cat stderr
  assert_prints start metrics_files
}

# catches: a folder named like a new file of a killed collector stopping every collection with rm's own words:
# the collector makes no folder there, so it is none of its files and is left alone.
test_a_folder_named_like_a_killed_collectors_new_file_is_left_alone() {
  local dead
  started_project one-setup
  transcripts finished-run
  sleep 0 &
  dead=$!
  wait "$dead"
  mkdir "$METRICS/tasks.csv.new.$dead"
  collected
  assert_prints '' cat stderr
  assert_prints "counted.csv
start
tasks.csv
tasks.csv.new.$dead" metrics_files
}

# catches: a folder under the collector's own working name for a file (a process of the same number made it) met
# with rm's or the shell's own words, or a write half done.
test_a_folder_under_the_collectors_own_working_name_is_refused_and_nothing_written() {
  local pid
  started_project one-setup
  transcripts finished-run
  run_collector_after_a_folder_under_its_working_name
  pid="$(<collector-pid)"
  assert_prints 1 cat status
  assert_prints "error: ctxm/metrics/tasks.csv.new.$pid is a folder where the collector keeps a working file;\
 remove it; nothing was written" cat stderr
  assert_prints "start
tasks.csv.new.$pid" metrics_files
}

# Runs the collector with a folder made under its working name for tasks.csv, by the shell that becomes it, so of its
# process id, noted in ./collector-pid; ./stdout, ./stderr and ./status as run_collector leaves them.
run_collector_after_a_folder_under_its_working_name() {
  local status=0
  # shellcheck disable=SC2016 # the $ names are the inner shell's
  in_collector_environment bash -c 'mkdir "$1/tasks.csv.new.$$"; printf "%s\n" "$$" >collector-pid; exec "${@:2}"' \
    _ "$METRICS" "$COLLECTOR" --project "$PWD/project" --transcripts "$PWD/transcripts" >stdout 2>stderr \
    || status=$?
  printf '%s\n' "$status" >status
}

# Runs the collector as a git hook would: with the variables of another repository.
run_collector_with_git_variables() {
  local status=0
  in_collector_environment GIT_DIR="$PWD/decoy/.git" GIT_WORK_TREE="$PWD/decoy" GIT_INDEX_FILE="$PWD/decoy/.git/index" \
    GIT_NAMESPACE=synthetic "$COLLECTOR" --project "$PWD/project" --transcripts "$PWD/transcripts" \
    >stdout 2>stderr || status=$?
  printf '%s\n' "$status" >status
}

run_tests
