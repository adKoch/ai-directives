#!/usr/bin/env bash
# A stand-in for `mv` that interrupts the collector at its last step: it sends TERM to the process that called it
# and moves nothing, as if the collection were stopped just before its rename.
kill -TERM "$PPID"
exit 1
