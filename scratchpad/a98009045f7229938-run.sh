#!/bin/sh
# a98009045f7229938 -- configure + build one 47-base tree, detached.
#
# Named for the full worktree id per PRINCIPLES ("/tmp/b<task number> IS NOT
# YOUR OWN": task numbers are handed out in neighbouring blocks and collide by
# construction; a worktree id does not).
#
# usage: a98009045f7229938-run.sh <tag>       tag is `pre' or `post'
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
ID=$(basename "$W")
TAG=${1:?tag}
SNAP=${SNAP:?set SNAP to the immutable snapshot}
# `b-<hash>', NOT `b-agent-<hash>': mt_assert_builddir derives the tag from
# mt-lib.sh's own path WITHOUT the `agent-' prefix and refuses anything else.
# Measured by having it refuse `/tmp/b-agent-...' on the first launch.
D=/tmp/b-${ID#agent-}-$TAG
LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | paste -sd, -)
# MEASURED from the snapshot, never copied from a brief; PRINCIPLES records
# ten different values for this line.  Exported because mt-build.sh asserts it
# too and a missing WANT_ANCHOR there stops the run AFTER configure has spent
# its minutes -- which reads as a configure failure.
N=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in")
export WANT_ANCHOR=$N
echo "== $TAG snap=$SNAP anchor=$N bases=$(echo "$LIST" | tr ',' '\n' | grep -c .)"
SRC=$SNAP WANT_ANCHOR=$N sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST"
# -j: MT_MAKEFLAGS unset means -j1 SILENTLY, which reads as "the build is slow"
# rather than "the build was never parallel".  Stated, not defaulted in place.
MT_MAKEFLAGS=${MT_MAKEFLAGS:--j8} sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
echo "== $TAG done rc=$(cat "$D/all-gcc.rc" 2>/dev/null || echo NONE)"
