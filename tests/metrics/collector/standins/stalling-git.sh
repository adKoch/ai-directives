#!/usr/bin/env bash
# A stand-in for `git` that stalls, so a test can send the collector a signal while it waits for git. It notes its own
# process id in `git-stalled` beside its link and waits until that process is signalled.
printf '%s\n' "$$" >"${0%/*}/git-stalled"
exec sleep 60
