#!/usr/bin/env bash
# A stand-in for `wc` that fails as an unreadable file makes it fail, naming the file as it is: a path with a control
# character in it comes out raw, as a tool that does not quote prints it.
printf 'wc: %s: Permission denied\n' "${!#}" >&2
exit 1
