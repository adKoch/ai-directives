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

# catches: files a killed collector left (`<file>.new.<its process id>`, `<file>.old.<its process id>`) piling up
# in ctxm/metrics/ for good, or a collector that removes the file of another that still runs.
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
  printf 'x\n' >"$METRICS/tasks.csv.old.$dead"
  printf 'x\n' >"$METRICS/tasks.csv.new.$alive"
  printf 'x\n' >"$METRICS/notes.new.synthetic"
  collected
  kill "$alive"
  assert_prints "notes.new.synthetic
start
tasks.csv
tasks.csv.new.$alive" ls "$METRICS"
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

# Runs the collector as a git hook would: with the variables of another repository.
run_collector_with_git_variables() {
  local status=0
  in_collector_environment GIT_DIR="$PWD/decoy/.git" GIT_WORK_TREE="$PWD/decoy" GIT_INDEX_FILE="$PWD/decoy/.git/index" \
    GIT_NAMESPACE=synthetic "$COLLECTOR" --project "$PWD/project" --transcripts "$PWD/transcripts" \
    >stdout 2>stderr || status=$?
  printf '%s\n' "$status" >status
}

run_tests
