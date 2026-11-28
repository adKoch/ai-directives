#!/usr/bin/env bash
# A stand-in for `rm` that fails on a roll-up (a name ending in `.md`) and does what rm does for any other name: a new
# roll-up that a stopped collection cannot remove again.
case "${!#}" in
  *.md)
    printf 'rm: synthetic failure\n' >&2
    exit 1
    ;;
esac
PATH="${PATH#"${0%/*}:"}"
exec rm "$@"
