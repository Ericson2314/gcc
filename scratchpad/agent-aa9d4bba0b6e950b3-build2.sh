#!/bin/sh
# agent-aa9d4bba0b6e950b3-build2.sh -- build the AFTER (fixed) 47-base tree.
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
D=/tmp/b-aa9d4bba0b6e950b3-after
TAG=${1:-all-gcc}
A=$(grep -c MULTI_TARGET /tmp/snap2-agent-aa9d4bba0b6e950b3/gcc/Makefile.in)
WANT_ANCHOR=$A MT_JOBS=${MT_JOBS:-12} sh "$W/scratchpad/mt-build.sh" "$D" "$TAG" all-gcc
