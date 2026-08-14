#!/bin/sh
# #167 -- IMMUTABLE SNAPSHOT of this worktree HEAD.  PRINCIPLES 4: NEVER BUILD
# FROM THE LIVE WORKING TREE (a torn read names real symbols and diagnoses a
# state that never existed in any commit).
#
# Re-run after every commit; the snapshot is what the build dir points at.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
SNAP=${1:?snap dir}
cd "$SRC"
git diff --quiet || { echo "FATAL: $SRC dirty; snapshot would not be HEAD"; exit 9; }
SHA=$(git rev-parse HEAD)
git worktree remove --force "$SNAP" >/dev/null 2>&1 || true
rm -rf "$SNAP"
git worktree add --detach "$SNAP" "$SHA" >/dev/null 2>&1 || { echo "FATAL: worktree add $SNAP"; exit 9; }
WANT=${WANT_ANCHOR:-54}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: snapshot anchor=$n, expected exactly $WANT"; exit 9; }
echo "snapshot $SNAP at $SHA anchor=$n OK"
