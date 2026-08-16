#!/bin/sh
# agent-a018835bbcfad2e28-drive.sh -- snapshot HEAD, configure the 47-base set,
# build all-gcc.  Detached by the caller (setsid nohup); this script itself is
# plain so its rc lands in the stamps mt-build.sh writes.
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
ID=agent-a018835bbcfad2e28
SHA=$(cd "$W" && git rev-parse --short HEAD)
SNAP=/tmp/snap-$ID-$SHA
B=/tmp/b-a018835bbcfad2e28

A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
export WANT_ANCHOR=$A
echo "anchor=$A sha=$SHA snap=$SNAP build=$B"

# 1. immutable snapshot, named for the sha as well as the worktree
if [ ! -f "$SNAP/SNAP-SHA" ]; then
  chmod -R u+w "$SNAP" 2>/dev/null || true
  rm -rf "$SNAP"; mkdir -p "$SNAP"
  ( cd "$W" && git archive HEAD ) | tar -x -C "$SNAP"
  echo "$SHA" > "$SNAP/SNAP-SHA"
  chmod -R a-w "$SNAP"
fi
[ "$(cat "$SNAP/SNAP-SHA")" = "$SHA" ] || { echo "FATAL: snapshot sha mismatch"; exit 9; }

LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep . | paste -sd,)
echo "bases: $(printf '%s' "$LIST" | tr , '\n' | wc -l)"

SRC=$SNAP sh "$W/scratchpad/mt-conf.sh" "$B" "$LIST"
MT_JOBS=${MT_JOBS:-12} sh "$W/scratchpad/mt-build.sh" "$B" all-gcc all-gcc
echo "DRIVE DONE rc=$?"
