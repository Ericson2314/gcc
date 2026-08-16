#!/bin/sh
# agent-a260445cf27ba480a -- immutable snapshot, path carries worktree id AND sha.
# usage: agent-a260445cf27ba480a-snap.sh [sha-ish]
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W"
REF=${1:-HEAD}
SHA=$(git rev-parse --short "$REF")
S=/tmp/snap-agent-a260445cf27ba480a-$SHA
chmod -R u+w "$S" 2>/dev/null || true
rm -rf "$S"
mkdir -p "$S"
git archive "$REF" | tar -x -C "$S"
git rev-parse --short "$REF" > "$S/SNAP-SHA"
chmod -R a-w "$S"
echo "snap $S sha=$SHA anchor=$(grep -c MULTI_TARGET "$S/gcc/Makefile.in")"
