#!/bin/sh
# #136 -- make an IMMUTABLE SNAPSHOT of this worktree's HEAD.
#
# `git archive' rather than a second git worktree: the result has no .git at
# all, so "the sources changed under the build" is not merely checked for, it
# is impossible.  The anchor is recomputed FROM THE SNAPSHOT, never copied.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?snapshot dir}
WANT=${WANT_ANCHOR:?set WANT_ANCHOR from `grep -c MULTI_TARGET gcc/Makefile.in`}

( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is dirty; HEAD would not be what you tested"; exit 9; }
SHA=$(cd "$SRC" && git rev-parse HEAD)

if [ -d "$D" ]; then chmod -R u+w "$D"; fi	# a previous snapshot is read-only
rm -rf "$D"; mkdir -p "$D"
( cd "$SRC" && git archive HEAD ) | tar -x -C "$D"
echo "$SHA" > "$D/SNAP-SHA"
chmod -R a-w "$D" 2>/dev/null || true

n=$(grep -c MULTI_TARGET "$D/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: snapshot anchor=$n, expected exactly $WANT"; exit 9; }
echo "snapshot $D  sha=$SHA  anchor=$n"
