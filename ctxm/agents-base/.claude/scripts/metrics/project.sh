# shellcheck shell=bash
# What the collector reads of the project: its folder, its name and, from its git history, the setup it had at
# each commit that changed the lock or an agent file. Read-only: no git command here writes.
# Sourced by collect-metrics.sh; needs refuse (tools.sh) and metrics_jq (program.sh).

readonly LOCK_FILE=.ctxm/ctxm.lock AGENTS_FOLDER=.claude/agents

# Sets PROJECT to the project's folder, or ends the collector: the folder must be the top of the project's main
# checkout, so a project has one ctxm/metrics/ however many worktrees it has.
find_project() {
  local folder=$1 top
  [[ -d "$folder" ]] || refuse "the project folder is no folder; name the project's main checkout with --project"
  PROJECT="$(cd -- "$folder" && pwd -P)"
  top="$(project_git rev-parse --show-toplevel 2>/dev/null)" || top=''
  [[ "$top" == "$PROJECT" ]] || refuse "the project folder is not the top of a git checkout; name the project's" \
    "main checkout with --project"
  [[ "$(project_git rev-parse --absolute-git-dir)" == "$PROJECT/.git" ]] || refuse "the project folder is a linked" \
    "worktree; run the collector in the project's main checkout, the one place of its ctxm/metrics/"
  readonly PROJECT
}

# A user's setting that adds lines to the log (a signature) would be read as commits: it is turned off.
project_git() {
  git --no-pager -c log.showSignature=false -C "$PROJECT" "$@"
}

# Drops every git variable of the caller's environment (inside a git hook there are several: GIT_DIR,
# GIT_INDEX_FILE, an object folder, a namespace): every git command here reads the repository of the project folder
# and no other.
forget_inherited_repository() {
  local name
  for name in "${!GIT_@}"; do
    unset "$name"
  done
}

# Prints the project's name, its main checkout's folder name, or nothing when that is no plain name.
project_name() {
  # shellcheck disable=SC2016 # $name is jq's
  metrics_jq format '$name | select(is_project_name)' --null-input --raw-output --arg name "${PROJECT##*/}"
}

# Prints the project's setups, newest first, one JSON object per line (setup.jq): one per commit on the checked
# out branch that changed the lock or an agent file. A project without a commit has none.
project_setups() {
  local changes change
  project_git rev-parse --verify --quiet HEAD >/dev/null || return 0
  changes="$(project_git log --first-parent --format='%H %ct' HEAD -- "$LOCK_FILE" "$AGENTS_FOLDER")"
  while read -r -a change; do
    ((${#change[@]} == 0)) || setup_at_commit "${change[@]}"
  done < <(printf '%s\n' "$changes")
}

# Prints the setup at one commit, from the lock and the agent files as that commit holds them. They reach jq on its
# input, never as arguments: an argument has a size limit that a file does not.
setup_at_commit() {
  local commit=$1 since=$2
  # shellcheck disable=SC2016 # $commit and $since are jq's
  setup_files_at "$commit" | metrics_jq "format setup" '
    [inputs] as $files
    | setup($commit; $since; $files | map(.lock // empty) | .[0]; $files | map(select(has("role"))))
  ' --null-input --compact-output --arg commit "$commit" --argjson since "$since"
}

# Prints the lock of a commit as {lock: <text>}, if it has one, then each of its agent files as {role, text}.
setup_files_at() {
  local commit=$1
  if project_git cat-file -e "$commit:$LOCK_FILE" 2>/dev/null; then
    project_git show "$commit:$LOCK_FILE" | jq --raw-input --slurp --compact-output '{lock: .}'
  fi
  agent_files_at "$commit"
}

# Prints each agent file of a commit as {role, text}, one JSON object per line. A name git has to quote is no
# role: its file is not read, and its entry has no role.
agent_files_at() {
  local commit=$1 paths path
  paths="$(project_git ls-tree --name-only "$commit" "$AGENTS_FOLDER/")"
  while IFS= read -r path; do
    case "$path" in
      \"*) jq --null-input --compact-output '{role: "", text: ""}' ;;
      *.md) agent_file_at "$commit" "$path" ;;
    esac
  done < <(printf '%s\n' "$paths")
}

# Prints one agent file of a commit as {role, text}; the role is the file's name.
agent_file_at() {
  local commit=$1 path=$2 role="${2##*/}"
  # shellcheck disable=SC2016 # $role is jq's
  project_git show "$commit:$path" \
    | jq --raw-input --slurp --compact-output --arg role "${role%.md}" '{role: $role, text: .}'
}
