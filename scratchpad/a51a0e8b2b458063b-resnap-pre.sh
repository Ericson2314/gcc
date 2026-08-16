#!/bin/sh
# Restore /tmp/snap-agent-a51a0e8b2b458063b to the PRE commit at the SAME path
# the pre build dir was configured from.  See a51a0e8b2b458063b-snap.sh for why
# this had to be done once rather than never.
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
S=/tmp/snap-agent-a51a0e8b2b458063b
PRE=6bbccf3795c
chmod -R u+w "$S" 2>/dev/null || true
rm -rf "$S"; mkdir -p "$S"
cd "$W"
git archive "$PRE" | tar -x -C "$S"
git rev-parse --short "$PRE" > "$S/SNAP-SHA"
chmod -R a-w "$S"
echo "restored $S sha=$(cat "$S/SNAP-SHA") anchor=$(grep -c MULTI_TARGET "$S/gcc/Makefile.in")"
grep -n 'MIN_MODE_FLOAT <=' "$S/gcc/config/aarch64/aarch64-protos.h" \
  && echo "OK: the snapshot carries the UNFIXED AARCH64_APPROX_MODE" \
  || { echo "FATAL: this snapshot is not the pre tree"; exit 9; }
