#!/usr/bin/env bash
# A stand-in for `mv` that lets the collector's first rename through and stops its second, as the file `mv-stop`
# beside its link says: `interrupt` makes the rename, then sends TERM to the process that called it (a stop right
# after a rename returns); `fail` moves nothing and fails as a full disk or a read-only folder makes it fail. Every
# other call is the real mv's, so a collector can put its files back. It counts its calls in `mv-calls`.
readonly TOOLS="${0%/*}"
calls=0
[[ ! -f "$TOOLS/mv-calls" ]] || calls="$(<"$TOOLS/mv-calls")"
calls=$((calls + 1))
printf '%s\n' "$calls" >"$TOOLS/mv-calls"
PATH="${PATH#"$TOOLS:"}"
((calls == 2)) || exec mv "$@"
case "$(<"$TOOLS/mv-stop")" in
  interrupt)
    mv "$@"
    kill -TERM "$PPID"
    ;;
  *)
    printf 'mv: synthetic failure\n' >&2
    exit 1
    ;;
esac
