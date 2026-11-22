#!/usr/bin/env bash
# Builds synthetic Claude Code transcripts from a shape, in the layout Claude Code keeps for one project.
# Usage: make-transcripts.sh <shape.json> <transcripts folder> <epoch> [<minute>]
#   <shape.json>  the sessions, their events and their runs (tests/metrics/fixtures/transcripts/, README.md)
#   <epoch>       the time the shape's minute 0 stands for, as 2026-01-05T09:00:00Z
#   <minute>      build the files as they stand that many minutes after the epoch (default: when all is written);
#                 building again with a later minute lets the transcripts grow as real ones do
# Nothing is written unless the whole shape builds.
set -euo pipefail

SUPPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SUPPORT
# shellcheck source=files.sh
source "$SUPPORT/files.sh"

main() {
  local shape=$1 folder=$2 epoch=$3 minute=${4:-null} files
  files="$(jq --compact-output -L "$SUPPORT" --arg epoch "$epoch" --argjson minute "$minute" '
    include "layout"; include "records";
    transcript_layout($minute // infinite) | {file, content: file_content($epoch)}
  ' "$shape")"
  write_files "$folder" <<<"$files"
}

main "$@"
