#!/bin/sh
# #158 / PART A -- make an IMMUTABLE SNAPSHOT of this worktree's HEAD to build
# from.  PRINCIPLES section 4: NEVER BUILD FROM THE LIVE WORKING TREE.  A torn
# read looks exactly like a real defect and it names real symbols.
#
# usage: t158-snap.sh <snapdir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
SNAP=${1:?snap dir}

# The tree must be CLEAN, or the snapshot is not the thing under test.
cd "$SRC"
git diff --quiet || { echo "FATAL: $SRC has unstaged changes; snapshot would not be HEAD"; exit 9; }
SHA=$(git rev-parse HEAD)

rm -rf "$SNAP"
git worktree add --detach "$SNAP" "$SHA" >/dev/null 2>&1 \
  || { echo "FATAL: git worktree add failed"; exit 9; }

# Assert the ANCHOR on the SNAPSHOT, not on the live tree: the snapshot is what
# gets built, so it is what must be checked.  EXACT, never `>=' -- the number is
# not the invariant, the exactness is (PRINCIPLES section 4).
WANT=${WANT_ANCHOR:-48}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: snapshot anchor=$n, expected exactly $WANT"; exit 9; }
grep -q 'gcc_backends_arg' "$SNAP/configure" \
  || { echo "FATAL: $SNAP/configure has no gcc_backends_arg mapping"; exit 9; }

echo "snapshot $SNAP at $SHA anchor=$n OK"
