#!/bin/sh
# TASK #113 -- every SHARED spelling of the move/clear family, with enough
# context to judge whether it is a CONSTANT-EXPRESSION context.
#
# This is the sweep defaults.h's own comment says has to happen before a
# redirect lands: `#if', a case label, an array bound or a static initialiser
# cannot hold a function call, and a redirect into one of those is a compile
# error at best and a silently different constant at worst.
#
# MAX_MOVE_MAX is on the list precisely because it is the one that looks like
# an array bound, and if it is one, it CANNOT be converted -- which would
# decide the shape of the whole group.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098
G=$W/gcc
A=${A:-/tmp/t113-armD2}
[ -s "$A/shared-files.txt" ] || { echo "FATAL: run t113-armD2.sh first"; exit 9; }
for m in MOVE_RATIO CLEAR_RATIO SET_RATIO MOVE_MAX MOVE_MAX_PIECES \
         STORE_MAX_PIECES COMPARE_MAX_PIECES MAX_MOVE_MAX; do
  echo "=== $m"
  grep -nw "$m" $(cat "$A/shared-files.txt") | sed "s#$G/##"
done
