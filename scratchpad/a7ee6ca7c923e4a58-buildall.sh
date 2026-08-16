#!/bin/sh
# Snapshot + configure + build the 47-base tree for this worktree, detached.
# Every value is MEASURED here rather than copied: WANT_ANCHOR is read off the
# tree being snapshotted, so a tree that is not the one intended fails inside
# mt-conf.sh by name instead of producing a green for another compiler.
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7ee6ca7c923e4a58
ID=agent-a7ee6ca7c923e4a58
SNAP=/tmp/snap-$ID
D=/tmp/b-a7ee6ca7c923e4a58

A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
echo "== anchor measured on the worktree: $A"
export WANT_ANCHOR=$A

# 1. IMMUTABLE snapshot -- never the live tree (PRINCIPLES 4/5).
chmod -R u+w "$SNAP" 2>/dev/null || true
rm -rf "$SNAP"; mkdir -p "$SNAP"
( cd "$W" && git archive HEAD ) | tar -x -C "$SNAP"
( cd "$W" && git rev-parse --short HEAD ) > "$SNAP/SNAP-SHA"
chmod -R a-w "$SNAP"
echo "== snapshot $(cat "$SNAP/SNAP-SHA") at $SNAP"

# 2. configure with the 47 TRIPLES (not bare back-end names -- INSTRUMENTS.md).
LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep . | paste -sd,)
nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" = 47 ] || { echo "FATAL: $nt triples, expected 47"; exit 9; }
SRC=$SNAP sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST"

# 3. build
MT_JOBS=${MT_JOBS:-12} sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
echo "== all-gcc rc=$(cat "$D/all-gcc.rc")"
