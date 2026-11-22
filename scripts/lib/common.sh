# shellcheck shell=bash
# Shared by the library's scripts. Every script starts with:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#   require_tools <each command it calls>
#   ensure_budget "$@"
# The library ships no toolchain: the caller's provides the tools (README.md, Tools). So a script checks its tools
# before anything else, and takes its time budget next (the budget itself needs `timeout`).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT
# Logs and scratch files, a folder per step.
readonly CACHE_DIR="$REPO_ROOT/.cache"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Prints the calling script's absolute path, for running it again.
script_path() {
  printf '%s/%s\n' "$(cd "$(dirname "$0")" && pwd)" "$(basename "$0")"
}

# Prints the calling script's path for a message: from the library's root when it is inside, otherwise absolute.
shown_script_path() {
  local path
  path="$(script_path)"
  printf '%s\n' "${path#"$REPO_ROOT"/}"
}

# Makes the cache's folder of that name. The cache ignores itself, so the checkout stays clean without a line in a
# tracked file.
make_ignored_cache_folder() {
  mkdir -p "$CACHE_DIR/$1"
  [[ -f "$CACHE_DIR/.gitignore" ]] || printf '*\n' >"$CACHE_DIR/.gitignore"
}

# shellcheck source=tools.sh
source "$REPO_ROOT/scripts/lib/tools.sh"
# shellcheck source=budget.sh
source "$REPO_ROOT/scripts/lib/budget.sh"
