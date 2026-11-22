#!/usr/bin/env bash
# A stand-in for a script that runs over its budget: it starts a process, writes that process's PID to the file it
# is given and never ends by itself.
# shellcheck source=../../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../common.sh"
ensure_budget "$@"

sleep 60 &
printf '%s\n' "$!" >"$1"
wait
