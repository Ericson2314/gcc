#!/bin/sh
# mt-snap.sh -- make an immutable snapshot of a commit, for THIS worktree.
#
# The generic form of `a51a0e8b2b458063b-snap.sh', which is byte-for-byte this
# script with `/tmp/snap-agent-a51a0e8b2b458063b-' hardcoded.  INSTRUMENTS.md
# records that a hardcoded per-worktree path is the single thing that forced
# 63 copies of `*-conf.sh'; `mt-lib.sh' derives the tag from the script's own
# location instead, and so does this.  If you find yourself editing one line
# here to make it run, that line is the bug.
#
# THE SHA IS PART OF THE PATH, AND THAT IS NOT TIDINESS.  A build dir records
# its srcdir in `MY-SRC'/`config.log' and every later harness re-reads files
# FROM IT (mt-bars.sh takes `big.c' from the srcdir; rebuilding one object
# recompiles the srcdir's source).  Overwriting one snapshot path with a
# different commit silently re-points an already-configured build dir at code
# it was not built from, and the rebuild SUCCEEDS while measuring the other
# commit -- a green everywhere.  PRINCIPLES records that near-miss.
#
# usage: mt-snap.sh [<sha-ish>]      default HEAD
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
ID=$(basename "$W")
REF=${1:-HEAD}
cd "$W"
SHA=$(git rev-parse --short "$REF")
S=/tmp/snap-$ID-$SHA
chmod -R u+w "$S" 2>/dev/null || true
rm -rf "$S"
mkdir -p "$S"
git archive "$REF" | tar -x -C "$S"
echo "$SHA" > "$S/SNAP-SHA"
chmod -R a-w "$S"
# Print the anchor rather than asserting it: this script does not know which
# value the caller expects, and `mt-conf.sh' asserts it EXACTLY from
# WANT_ANCHOR.  Two authorities for one fact is this branch's own root bug.
echo "snap $S sha=$SHA anchor=$(grep -c MULTI_TARGET "$S/gcc/Makefile.in")"
