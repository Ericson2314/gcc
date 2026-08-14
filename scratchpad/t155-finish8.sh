#!/bin/sh
# #155 -- wait for the 8-base build, then score it and run the per-base arm.
#
# One script rather than three round trips, and it refuses to score anything
# before the .rc stamp exists: a log being written looks exactly like a log
# that finished.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=/tmp/b-af064528c538fd406-8
until [ -f "$D/eight.rc" ]; do sleep 60; done
echo "=== stamped rc=$(cat "$D/eight.rc")"
sh "$S/t155-score.sh" "$D" eight
echo
echo "=== per-base definition sweep"
sh "$S/t155-before-defs.sh" "$D" i386 aarch64 rs6000 m68k microblaze pdp11 vax xtensa
