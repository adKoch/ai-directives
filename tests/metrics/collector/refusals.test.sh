#!/usr/bin/env bash
# What the collector refuses before it writes: a missing tool, a link where it reads or writes, a setup it
# cannot read, a place that is not the project's main checkout. A refusal is one line, exit 1, nothing written.
# shellcheck source=collecting.sh
source "$(dirname "${BASH_SOURCE[0]}")/collecting.sh"

# What the collector calls, without jq.
readonly TOOLS_WITHOUT_JQ=(bash git ln mkdir mv rm wc)
readonly ONLY_THE_START='?? ctxm/metrics/start'

# Fails unless the last run of the collector was refused with that line (given in parts, joined by spaces) and
# the project holds no new file but the ones named first.
assert_refused() {
  local new_files=$1
  shift
  assert_prints 1 cat status
  assert_prints "error: $*" cat stderr
  assert_prints '' cat stdout
  assert_prints "$new_files" written_files
}

# catches: a collector that reads or writes although a required tool is missing, or whose line no longer names
# the tool and the requirement.
test_without_jq_the_collector_names_it_and_writes_nothing() {
  local tool
  project one-setup
  transcripts finished-run
  mkdir tools
  for tool in "${TOOLS_WITHOUT_JQ[@]}"; do
    ln -s "$(command -v "$tool")" "tools/$tool"
  done
  PATH="$PWD/tools" collect
  assert_refused '' "collect-metrics.sh needs jq: not on the PATH; the project's toolchain must provide" \
    "bash 4.4 or later, jq, git, ln, mkdir, mv, rm and wc"
}

# catches: a write that follows a link out of the project: the start record or the lines would land wherever
# the link points.
test_a_linked_metrics_folder_or_lines_file_is_refused_and_nothing_lands_behind_the_link() {
  project one-setup
  transcripts finished-run
  mkdir outside project/ctxm
  ln -s "$PWD/outside" "$METRICS"
  collect
  assert_refused '?? ctxm/metrics' "ctxm/metrics is a symbolic link: the collector writes only the project's own" \
    "ctxm/metrics/; remove the link; nothing was written"
  rm "$METRICS"
  mkdir "$METRICS"
  printf '2026-01-01T00:00:00Z\n' >"$METRICS/start"
  ln -s "$PWD/outside/tasks.csv" "$METRICS/tasks.csv"
  collect
  assert_prints 1 cat status
  assert_prints "error: ctxm/metrics/tasks.csv is a symbolic link: the collector writes only the project's own\
 ctxm/metrics/; remove the link; nothing was written" cat stderr
  assert_prints '' ls outside
}

# catches: a transcript read through a link: the collector would take numbers, and a task name, from a file
# outside the folder it was given.
test_a_link_in_the_transcripts_folder_is_refused() {
  started_project one-setup
  transcripts finished-run
  mv transcripts elsewhere
  mkdir transcripts
  ln -s "$PWD/elsewhere/aaaaaaaa-0000-4000-8000-000000000001" transcripts/aaaaaaaa-0000-4000-8000-000000000001
  collect
  assert_refused "$ONLY_THE_START" "the transcripts folder holds 1 symbolic link(s) on the way to its transcripts;" \
    "the collector follows none: remove them; nothing was written"
}

# catches: a lock in a format the collector does not know read as if it were ctxm 0.7's: lines under a wrong or
# empty list of templates.
test_a_lock_in_another_format_is_refused_naming_the_file() {
  local commit
  started_project later-lock-format
  transcripts finished-run
  commit="$(git -C project rev-parse HEAD)"
  collect
  assert_refused "$ONLY_THE_START" "the setup at commit $commit: .ctxm/ctxm.lock is not in the lock format" \
    "ctxm 0.7 writes (version 6); nothing was written"
}

# catches: a control character from an agent file copied into a line of tasks.csv.
test_an_effort_with_a_control_character_is_refused() {
  local commit
  started_project effort-with-control-character
  transcripts finished-run
  commit="$(git -C project rev-parse HEAD)"
  collect
  assert_refused "$ONLY_THE_START" "the setup at commit $commit: an agent file of .claude/agents/ names an effort" \
    "that is no plain word; nothing was written"
}

# catches: a collection stopped at its last step that leaves half a file, or the file it was preparing.
test_an_interrupted_collection_leaves_the_lines_as_they_were() {
  started_project one-setup
  transcripts unfinished-and-unnamed-runs 10
  collected
  cp "$METRICS/tasks.csv" before.csv
  transcripts unfinished-and-unnamed-runs
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/interrupting-mv.sh" tools/mv
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
  assert_same_content "$METRICS/tasks.csv" before.csv
  assert_prints 'counted.csv
start
tasks.csv' metrics_files
}

# catches: a step that fails with status 1 (a full disk, a read-only folder) ending the collector without its
# error line, as if it were a refusal that had printed one.
test_a_step_that_fails_ends_the_collector_with_one_error_line_and_nothing_written() {
  started_project one-setup
  transcripts finished-run
  mkdir tools
  ln -s "$COLLECTOR_TESTS/standins/failing-mv.sh" tools/mv
  PATH="$PWD/tools:$PATH" collect
  assert_prints 1 cat status
  assert_prints 'mv: synthetic failure
error: a step of the collection failed, see above; ctxm/metrics/ holds no half-written file' cat stderr
  assert_prints start ls "$METRICS"
}

# catches: a collection that is done reported as failed, with a write error, when stdout is closed.
test_a_collection_with_stdout_closed_is_done_quietly() {
  local status=0
  started_project one-setup
  transcripts finished-run
  "$COLLECTOR" --project "$PWD/project" --transcripts "$PWD/transcripts" >&- 2>stderr || status=$?
  assert_equal "$status" 0
  assert_prints '' cat stderr
  assert_prints 2 line_count
}

# catches: a first collection that starts the metrics of a project no later collection can collect.
test_a_first_collection_in_a_folder_whose_name_is_no_plain_name_is_refused() {
  project one-setup
  transcripts finished-run
  mv project 'synthetic project'
  run_collector --project "$PWD/synthetic project" --transcripts "$PWD/transcripts"
  assert_prints 1 cat status
  assert_prints "error: the project folder's name is no plain name, so no line can name the project" cat stderr
  assert_prints '' git -C 'synthetic project' status --porcelain --untracked-files=all
}

# catches: a second set of metrics on a branch: a collection in a linked worktree would write its own
# ctxm/metrics/ there.
test_a_linked_worktree_is_refused() {
  started_project one-setup
  transcripts finished-run
  git -C project worktree add --quiet "$PWD/linked" HEAD
  run_collector --project "$PWD/linked" --transcripts "$PWD/transcripts"
  assert_refused "$ONLY_THE_START" "the project folder is a linked worktree; run the collector in the project's" \
    "main checkout, the one place of its ctxm/metrics/"
  assert_prints '' git -C linked status --porcelain --untracked-files=all
}

# catches: an option the collector does not have taken for a folder or passed over.
test_an_unknown_option_is_refused_with_the_usage() {
  started_project one-setup
  transcripts finished-run
  collect_with --since yesterday
  assert_refused "$ONLY_THE_START" \
    'usage: collect-metrics.sh [--dry-run] [--project <folder>] [--transcripts <folder>]'
}

# catches: a dry run that writes.
test_a_dry_run_says_what_it_would_add_and_writes_nothing() {
  started_project one-setup
  transcripts finished-run
  collect_with --dry-run
  assert_prints 0 cat status
  assert_prints 'ctxm/metrics/tasks.csv: lines to add: 2 (of runs: 1, of main sessions: 1); dry run, nothing written' \
    cat stdout
  assert_prints "$ONLY_THE_START" written_files
}

run_tests
