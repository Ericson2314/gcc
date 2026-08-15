#!/bin/sh
# agent-aa9d4bba0b6e950b3-conf2.sh -- configure the AFTER build dir (the fixed
# tree) beside the BEFORE one, so the two can be compared by name.
#
# A SECOND BUILD DIR AND A SECOND SNAPSHOT, not a rebuild in place: mt-build.sh
# asserts that the build dir was configured from the srcdir it is given, and a
# rebuild would have destroyed the baseline the whole comparison rests on.
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
SNAP=/tmp/snap2-agent-aa9d4bba0b6e950b3
D=/tmp/b-aa9d4bba0b6e950b3-after

LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep . | paste -sd,)
n=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: $n triples, expected 47" >&2; exit 9; }

A=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in")
echo "snapshot anchor=$A sha=$(cat "$SNAP/SNAP-SHA")"
SRC=$SNAP WANT_ANCHOR=$A sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST"
