#!/usr/bin/env bash
# A stand-in for `mv` that lets the collector's renames through and stops one, as the file `mv-stop` beside its link
# says: `<mode> [<n>]`, the n-th call of `mv` being the one stopped (the second when n is left out):
#   interrupt-after   makes the rename, then sends TERM to the process that called it (a stop right after it returns)
#   interrupt-before  sends TERM and moves nothing (a stop between two renames, the later one not done)
#   fail              moves nothing and fails, as a full disk or a read-only folder makes it fail
#   fail-from-then-on fails as `fail` does on this call and every later one, so nothing can be put back either
# Every other call is the real mv's, so a collector can put its files back. It counts its calls in `mv-calls`.
readonly TOOLS="${0%/*}"
calls=0
[[ ! -f "$TOOLS/mv-calls" ]] || calls="$(<"$TOOLS/mv-calls")"
calls=$((calls + 1))
printf '%s\n' "$calls" >"$TOOLS/mv-calls"
PATH="${PATH#"$TOOLS:"}"
read -r mode stopped_call <"$TOOLS/mv-stop"
stopped_call="${stopped_call:-2}"
((calls == stopped_call)) || [[ "$mode" == fail-from-then-on && calls -gt stopped_call ]] || exec mv "$@"
case "$mode" in
  interrupt-after)
    mv "$@"
    kill -TERM "$PPID"
    ;;
  interrupt-before)
    kill -TERM "$PPID"
    exit 1
    ;;
  *)
    printf 'mv: synthetic failure\n' >&2
    exit 1
    ;;
esac
