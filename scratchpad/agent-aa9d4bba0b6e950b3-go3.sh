#!/bin/sh
# agent-aa9d4bba0b6e950b3-go3.sh -- configure AND build the third build dir,
# the one carrying BOTH fixes.  This is the tree the AFTER testsuite runs on.
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
SNAP=/tmp/snap3-agent-aa9d4bba0b6e950b3
D=/tmp/b-aa9d4bba0b6e950b3-both

LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep . | paste -sd,)
n=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: $n triples, expected 47" >&2; exit 9; }
A=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in")
echo "snapshot anchor=$A sha=$(cat "$SNAP/SNAP-SHA")"

SRC=$SNAP WANT_ANCHOR=$A sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST"
WANT_ANCHOR=$A MT_JOBS=${MT_JOBS:-8} sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
