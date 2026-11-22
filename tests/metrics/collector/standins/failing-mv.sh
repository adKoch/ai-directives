#!/usr/bin/env bash
# A stand-in for `mv` that fails as a full disk or a read-only folder makes it fail: status 1, and nothing moved.
printf 'mv: synthetic failure\n' >&2
exit 1
