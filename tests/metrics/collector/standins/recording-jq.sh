#!/usr/bin/env bash
# A stand-in for `jq` that is the real jq, and first writes each file it is given to read into `jq-files` beside
# its link: a test sees which files the collector read.
readonly TOOLS="${0%/*}"
for argument in "$@"; do
  [[ ! -f "$argument" ]] || printf '%s\n' "$argument" >>"$TOOLS/jq-files"
done
PATH="${PATH#"$TOOLS:"}"
exec jq "$@"
