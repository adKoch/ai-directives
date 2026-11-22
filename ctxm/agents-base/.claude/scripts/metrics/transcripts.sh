# shellcheck shell=bash
# What the collector reads of Claude Code's transcripts of the project:
#   <folder>/<session id>.jsonl                                   a main session
#   <folder>/<session id>/subagents/agent-<agent id>.jsonl        a run
#   <folder>/<session id>/subagents/agent-<agent id>.meta.json    whether the run has finished, and its role
# Each transcript becomes one line of facts (facts.jq): numbers, ids and checked names. No text of a transcript
# is printed, kept or passed on. Read-only.
# Sourced by collect-metrics.sh; needs refuse (tools.sh) and metrics_jq (program.sh).

# Prints the default transcripts folder of the project: where Claude Code keeps the sessions started in it.
default_transcripts_folder() {
  printf '%s/projects/%s\n' "${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}" "${PROJECT//[^A-Za-z0-9]/-}"
}

# Ends the collector when a symbolic link stands on the way to a transcript: the collector reads only files
# that are in the folder itself.
refuse_linked_transcripts() (
  local folder=$1 entry links=0
  shopt -s nullglob
  for entry in "$folder"/* "$folder"/*/subagents "$folder"/*/subagents/*; do
    [[ ! -L "$entry" ]] || links=$((links + 1))
  done
  ((links == 0)) || refuse "the transcripts folder holds $links symbolic link(s) on the way to its transcripts;" \
    "the collector follows none: remove them; nothing was written"
)

# Prints the facts of every main session's transcript in the folder, one JSON object per line.
session_facts() (
  local folder=$1 transcript
  shopt -s nullglob
  for transcript in "$folder"/*.jsonl; do
    metrics_jq "format facts" 'transcript_facts + {kind: "session"}' \
      --null-input --raw-input --compact-output "$transcript"
  done
)

# Prints the facts of every run's transcript in the folder, one JSON object per line. A run that has its line
# ($2 lists the written agent ids, each between spaces) is not read again.
run_facts() (
  local folder=$1 written=$2 transcript agent
  shopt -s nullglob
  for transcript in "$folder"/*/subagents/agent-*.jsonl; do
    agent="${transcript##*/agent-}"
    agent="${agent%.jsonl}"
    [[ "$written" == *" $agent "* ]] || one_run_facts "$transcript" "$agent"
  done
)

# Prints the facts of one run: its transcript's, and what its `.meta.json` says. A run whose file name holds no
# agent id is unreadable, and its name is not kept.
one_run_facts() {
  local transcript=$1 agent=$2 state_file="${1%.jsonl}.meta.json" state=(--arg state '')
  [[ ! -f "$state_file" ]] || state=(--rawfile state "$state_file")
  # shellcheck disable=SC2016 # $state and $agent are jq's
  metrics_jq "format facts" '
    transcript_facts + {kind: "run"} | with_run_state($state)
    | if ($agent | is_agent_id) then .agent = $agent else .agent = "" | .unreadable += 1 end
  ' --null-input --raw-input --compact-output --arg agent "$agent" "${state[@]}" "$transcript"
}
