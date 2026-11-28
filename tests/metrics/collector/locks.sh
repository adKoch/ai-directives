# shellcheck shell=bash
# What the tests of the lock share: a project whose one commit holds a lock built from JSON, and the check that a
# collection was refused for that lock, naming the commit and the file, echoing nothing and writing nothing.
# Sourced by lock-formats.test.sh and lock-lines.test.sh, after collecting.sh.

# shellcheck disable=SC2034 # read by the tests that source this file
readonly COMMIT_ONE=1111111111111111111111111111111111111111 COMMIT_TWO=2222222222222222222222222222222222222222
readonly NOTHING_BUT_THE_START='?? ctxm/metrics/start'
# shellcheck disable=SC2034 # read by the tests that source this file
readonly BAD_PIN="names a template version or a library commit that is none"
# shellcheck disable=SC2034 # read by the tests that source this file
readonly UNREAD_LINE="holds a line the collector does not read: a table, a key or a form ctxm does not write, or a \
key twice"

# Builds ./project from one commit holding a lock of the given format whose templates are the JSON list; the
# optional third argument, a JSON object, adds to the lock (`top_lines`, `end_lines`: tests/metrics/support/project.jq).
project_with_lock() {
  local format=$1 templates=$2 more=${3:-'{}'}
  project_with_lock_of "$(jq --null-input --compact-output --argjson format "$format" --argjson templates "$templates" \
    --argjson more "$more" '{version: $format, templates: $templates} + $more')"
}

# Builds ./project from one commit holding the lock file given, as it stands (a lock ctxm rendered: rendered-locks/).
project_with_lock_file() {
  project_with_lock_of "$(jq --null-input --compact-output --rawfile text "$1" '{text: $text}')"
}

# Builds ./project from one commit holding the lock text given, as it stands (a hand-edited lock no history renders).
project_with_lock_text() {
  project_with_lock_of "$(jq --null-input --compact-output --arg text "$1" '{text: $text}')"
}

# Builds ./project from one commit holding the lock the JSON object describes (tests/metrics/support/project.jq).
project_with_lock_of() {
  mkdir -p histories
  jq --null-input --argjson lock "$1" '
    {about: "a lock under test", commits: [{minute: -1440, lock: $lock,
      agents: [{name: "inspector", description: "synthetic-text inspector", model: "claude-synthetic-small",
        effort: "medium"}]}]}
  ' >histories/under-test.json
  SCENARIOS="$PWD" started_project under-test
}

# Collects a project whose lock is built as project_with_lock builds it, from a finished run, in a clean folder.
collect_with_lock() {
  collect_project_built_by project_with_lock "$@"
}

# Collects a project whose lock is the file given, as collect_with_lock does.
collect_with_lock_file() {
  collect_project_built_by project_with_lock_file "$1"
}

# Collects a project whose lock is the text given, as collect_with_lock does.
collect_with_lock_text() {
  collect_project_built_by project_with_lock_text "$1"
}

# Collects the project the command given builds (one of the project_with_lock functions), in a clean folder.
collect_project_built_by() {
  rm -rf project transcripts "$METRICS"
  "$@"
  transcripts finished-run
  collect
}

# Prints the lines as a JSON list, for a template's `extra_lines` or a lock's `top_lines` and `end_lines`.
json_lines() {
  jq --null-input '$ARGS.positional' --args "$@"
}

# Fails unless the last collection was refused in one line naming the commit, the lock and the problem, with the
# project holding nothing new but the start record.
assert_refused_for_the_lock() {
  local commit
  commit="$(git -C project rev-parse HEAD)"
  assert_prints 1 cat status
  assert_prints "error: the setup at commit $commit: .ctxm/ctxm.lock $1; fix it in a new commit: what ran under \
this one is then counted on stderr, not written; nothing was written" cat stderr
  assert_prints '' cat stdout
  assert_prints "$NOTHING_BUT_THE_START" written_files
}
