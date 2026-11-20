#!/usr/bin/env bash
# ctxm guard for Claude Code hooks.
#   pre:  refuses an edit to a ctxm-managed file (conflicted files may be edited to settle them).
#   post: after a tool call, reports managed files that changed and a broken ctxm state, once per new finding.
set -u
mode="${1:-}"
project="${CLAUDE_PROJECT_DIR:-$PWD}"
state_file="$project/ctxm/tmp/.ctxm-guard"

managed_states() {
  [ -d "$project/.ctxm" ] || return 3
  command -v ctxm >/dev/null 2>&1 || { echo "ctxm is not on PATH, so managed files cannot be checked"; return 4; }
  ctxm -C "$project" status --porcelain 2>&1
}

# Names the writers of porcelain status lines (fields 4 and on); "." is the project's own layer.
writers_awk='function writers(   w, i) { w = ""; for (i = 4; i <= NF; i++) w = w (w == "" ? "" : ", ") ($i == "." ? "the project'"'"'s own" : $i); return w }'

edited_path() {
  local input path
  input="$(cat)"
  if command -v jq >/dev/null 2>&1; then
    path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
  else
    path="$(printf '%s' "$input" | sed -n 's/.*"\(file_path\|notebook_path\)"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\2/p' | head -n1)"
  fi
  case "$path" in "$project"/*) path="${path#"$project"/}" ;; esac
  printf '%s' "$path"
}

guard_edit() {
  local path status line
  path="$(edited_path)"
  [ -n "$path" ] || exit 0
  case "$path" in .ctxm/*)
    echo "ctxm guard: .ctxm/ is ctxm's own state; never edit it." >&2; exit 2 ;;
  esac
  status="$(managed_states)" || exit 0
  line="$(printf '%s\n' "$status" | awk -F '\t' -v p="$path" '$1 == "file" && $2 == p')"
  [ -n "$line" ] || exit 0
  case "$(printf '%s' "$line" | cut -f3)" in
    conflicted) exit 0 ;;
  esac
  echo "ctxm guard: $path is managed by ctxm (written by $(printf '%s\n' "$line" | awk -F '\t' "$writers_awk { print writers() }"))" \
    "and read-only. A change to a template's part goes to that template; a change to the project's own part goes into" \
    "a draft. Describe it to main. See the ctxm skill." >&2
  exit 2
}

report_changes() {
  local status rc findings
  status="$(managed_states)"; rc=$?
  [ "$rc" -eq 3 ] && exit 0
  if [ "$rc" -eq 4 ]; then
    findings="$status"
  elif [ "$rc" -ne 0 ]; then
    findings="ctxm status failed (exit $rc): $status"
  else
    findings="$(printf '%s\n' "$status" | awk -F '\t' "$writers_awk"'
      $1 == "file" && ($3 == "modified" || $3 == "missing" || $3 == "unreadable") { print "  " $3 ": " $2 " (" writers() ")" }')"
  fi
  if [ -z "$findings" ]; then rm -f "$state_file"; exit 0; fi
  if [ -f "$state_file" ] && [ "$(cat "$state_file")" = "$findings" ]; then exit 0; fi
  mkdir -p "$(dirname "$state_file")" && printf '%s' "$findings" > "$state_file"
  { echo "ctxm guard: the ctxm setup changed. Stop and restore it before going on (see the ctxm skill):"
    echo "$findings"; } >&2
  exit 2
}

case "$mode" in
  pre) guard_edit ;;
  post) report_changes ;;
  *) echo "usage: ctxm-guard.sh pre|post" >&2; exit 1 ;;
esac
