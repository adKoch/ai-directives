#!/usr/bin/env bash
# A stand-in for `jq` that fails as jq does for a program that does not compile: status 3, a message of its own.
printf 'jq: error: synthetic compile failure\n' >&2
exit 3
