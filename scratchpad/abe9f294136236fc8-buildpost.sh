#!/bin/sh
# Configure + build the 47-base tree from the FIXED snapshot, detached.
#
# The snapshot path carries the SHA as well as the worktree id, per
# PRINCIPLES: a build dir re-reads its srcdir long after configure
# (`mt-bars.sh' takes `big.c' from it), so overwriting one snapshot path with
# a different commit silently re-points an already-configured PRE build dir at
# the FIXED source -- and the next arm reports the bug gone with a green
# everywhere.  PRE and POST therefore have different snapshot paths and
# different build dirs, and neither can reach the other's source.
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-abe9f294136236fc8
SNAP=/tmp/snap-agent-abe9f294136236fc8-fix
D=/tmp/b-abe9f294136236fc8-post

[ -f "$SNAP/SNAP-SHA" ] || { echo "FATAL: no snapshot at $SNAP"; exit 9; }
# THE ANCHOR IS READ OFF THE SNAPSHOT BEING BUILT, never off the worktree and
# never copied from a brief.  The worktree can move under a detached run.
A=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in")
echo "== anchor measured on $SNAP ($(cat "$SNAP/SNAP-SHA")): $A"
export WANT_ANCHOR=$A

# AND THE FIX MUST BE IN THE THING BEING BUILT.  A snapshot taken before the
# commit landed builds clean and reports the bug unfixed, which reads as "the
# fix did not work" rather than "you measured the wrong tree".
grep -q 'mt_stack_savearea_mode' "$SNAP/gcc/multi-target-macros.h" \
  || { echo "FATAL: $SNAP does not carry the STACK_SAVEAREA_MODE redirect"; exit 9; }
echo "== snapshot carries the redirect"

LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep . | paste -sd,)
nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" = 47 ] || { echo "FATAL: $nt triples, expected 47"; exit 9; }
SRC=$SNAP sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST"

MT_JOBS=${MT_JOBS:-12} sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
echo "== all-gcc rc=$(cat "$D/all-gcc.rc")"
