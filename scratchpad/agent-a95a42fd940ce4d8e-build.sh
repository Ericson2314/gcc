#!/bin/sh
# agent-a95a42fd940ce4d8e-build.sh -- configure+block-build the 47-base tree for
# the `extract_insn at recog.cc:2892' task.  No forked logic: it calls
# mt-conf.sh and mt-build.sh unmodified.
#
# The instruments run from THIS WORKTREE's scratchpad, not the snapshot's, and
# that is deliberate: mt-lib.sh derives the build-dir guard tag from the running
# script's own path, so a snapshot copy cannot derive one and refuses by name.
# SRC still points at the immutable snapshot, so nothing built here reads the
# live tree -- the two concerns are separate and only the srcdir must be frozen.
set -eu
ID=agent-a95a42fd940ce4d8e
SHA=4387bf9ce42
SRC=/tmp/snap-$SHA-$ID
# NOT /tmp/b-$ID: mt-lib.sh's guard expects `*/b-<hash>*' with NO `agent-'
# prefix, so INSTRUMENTS.md's worked example (`/tmp/b-$ID' with ID=agent-...)
# is refused by the very guard it demonstrates.  Following the guard.
B=/tmp/b-a95a42fd940ce4d8e
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/$ID
[ -r "$SRC/SNAP-SHA" ] || { echo "FATAL: no SNAP-SHA in $SRC"; exit 9; }
A=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$A" = 52 ] || { echo "FATAL: anchor $A != 52"; exit 9; }
LIST=$(grep -v '^#' "$SRC/scratchpad/backends-47.txt" | grep . | paste -sd,)
N=$(echo "$LIST" | tr ',' '\n' | wc -l)
[ "$N" = 47 ] || { echo "FATAL: $N triples, want 47"; exit 9; }
echo "anchor=$A triples=$N src=$SRC build=$B"
export WANT_ANCHOR=$A
export MT_MAKEFLAGS=${MT_MAKEFLAGS:--j8}
SRC=$SRC sh "$W/scratchpad/mt-conf.sh" "$B" "$LIST"
SRC=$SRC sh "$W/scratchpad/mt-build.sh" "$B" all-gcc all-gcc
echo "BUILD-DONE rc=$?"
