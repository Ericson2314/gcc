#!/bin/sh
# Task #185 -- make an immutable snapshot for this worktree.
#
# TWO SNAPSHOTS, TWO PATHS, DELIBERATELY.  A build dir records its srcdir in
# `MY-SRC'/`config.log' and every later harness re-reads files FROM IT
# (mt-bars.sh takes `big.c' from the srcdir; a rebuild of one object
# recompiles the srcdir's source).  Overwriting one snapshot path with a
# different commit therefore silently re-points an already-configured build
# dir at code it was not built from -- and the failure is invisible: the
# rebuild succeeds, and measures the other commit.  So the sha is part of the
# path.
#
# usage: abe9f294136236fc8-snap.sh <sha-ish> [suffix]
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
REF=${1:?sha-ish}
SUF=${2:-$REF}
S=/tmp/snap-agent-abe9f294136236fc8-$SUF
chmod -R u+w "$S" 2>/dev/null || true
rm -rf "$S"
mkdir -p "$S"
cd "$W"
git archive "$REF" | tar -x -C "$S"
git rev-parse --short "$REF" > "$S/SNAP-SHA"
chmod -R a-w "$S"
echo "snap $S sha=$(cat "$S/SNAP-SHA") anchor=$(grep -c MULTI_TARGET "$S/gcc/Makefile.in")"
