#!/bin/sh
# a76a331dcb554f700 -- immutable snapshot, sha IN THE PATH (see
# a51a0e8b2b458063b-snap.sh's header for why the sha, not just the worktree id).
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
REF=${1:-HEAD}
cd "$W"
SHA=$(git rev-parse --short "$REF")
S=/tmp/snap-agent-a76a331dcb554f700-$SHA
chmod -R u+w "$S" 2>/dev/null || true
rm -rf "$S"
mkdir -p "$S"
git archive "$REF" | tar -x -C "$S"
git rev-parse --short "$REF" > "$S/SNAP-SHA"
chmod -R a-w "$S"
echo "snap $S sha=$SHA anchor=$(grep -c MULTI_TARGET "$S/gcc/Makefile.in")"
