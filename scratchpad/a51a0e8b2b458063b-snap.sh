#!/bin/sh
# Task #185 -- make the immutable snapshot for this worktree.
set -eu
ID=agent-a51a0e8b2b458063b
W=$(cd "$(dirname "$0")/.." && pwd)
S=/tmp/snap-$ID
chmod -R u+w "$S" 2>/dev/null || true
rm -rf "$S"
mkdir -p "$S"
cd "$W"
git archive HEAD | tar -x -C "$S"
git rev-parse --short HEAD > "$S/SNAP-SHA"
chmod -R a-w "$S"
echo "snap $S sha=$(cat "$S/SNAP-SHA") anchor=$(grep -c MULTI_TARGET "$S/gcc/Makefile.in")"
