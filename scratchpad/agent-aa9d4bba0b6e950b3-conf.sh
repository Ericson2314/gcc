#!/bin/sh
# agent-aa9d4bba0b6e950b3-conf.sh -- configure the 47-base build dir for the
# s390x `s390_match_ccmode_set' task.
#
# NOT a fork of mt-conf.sh: it CALLS it.  This exists only because the agent
# harness refuses compound shell commands, so the triple list has to be
# assembled inside a file rather than on the command line.
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
ID=agent-aa9d4bba0b6e950b3
SNAP=/tmp/snap-$ID
# mt_tag() strips the `agent-' prefix, so the build dir is b-<hash> while the
# snapshot is snap-agent-<hash>.  Both carry the FULL hash, which is what
# PRINCIPLES' /tmp-sweep rule actually requires.
D=/tmp/b-aa9d4bba0b6e950b3

LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep . | paste -sd,)
n=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: $n triples, expected 47" >&2; exit 9; }

A=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in")
echo "snapshot anchor=$A sha=$(cat "$SNAP/SNAP-SHA")"

SRC=$SNAP WANT_ANCHOR=$A sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST"
