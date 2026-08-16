#!/bin/sh
# agent-a95a42fd940ce4d8e-rebuild.sh -- snapshot the FIXED tree under its own
# sha and build it in its OWN build dir, beside the unfixed one.
#
# TWO BUILD DIRS, NOT ONE REBUILT IN PLACE.  PRINCIPLES records a near-miss
# where a task overwrote the snapshot directory an already-configured build dir
# pointed at: a build dir re-reads its srcdir long after configure, so the next
# arm compiled the FIXED header and reported the bug gone with a green
# everywhere.  Keeping /tmp/b-a95a42fd940ce4d8e (PRE) untouched is what makes
# the before/after comparison mean anything, and the snapshot path carries the
# sha as well as the worktree id so it cannot be overwritten either.
set -eu
ID=agent-a95a42fd940ce4d8e
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/$ID
SHA=${SHA:?set SHA to the short sha of the fixed commit}
SRC=/tmp/snap-$SHA-$ID
B=/tmp/b-a95a42fd940ce4d8e-post
[ -d "$SRC" ] || { echo "FATAL: no snapshot $SRC"; exit 9; }
A=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
echo "anchor=$A (PRE build measured 52; report movement either way)"
export WANT_ANCHOR=$A
export MT_MAKEFLAGS=${MT_MAKEFLAGS:--j8}
LIST=$(grep -v '^#' "$SRC/scratchpad/backends-47.txt" | grep . | paste -sd,)
N=$(echo "$LIST" | tr ',' '\n' | wc -l)
[ "$N" = 47 ] || { echo "FATAL: $N triples, want 47"; exit 9; }
SRC=$SRC sh "$W/scratchpad/mt-conf.sh" "$B" "$LIST"
SRC=$SRC sh "$W/scratchpad/mt-build.sh" "$B" all-gcc all-gcc
echo "POST-BUILD-DONE"
