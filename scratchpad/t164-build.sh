#!/bin/sh
# #164 -- TOP-LEVEL all-gcc, with snapshot assertions and an rc stamp written
# only after make returns.  Adapted from t171-topbuild.sh.
# usage: t164-build.sh <builddir> [tag]
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:-top}
case "$D" in
  */b-a1c6fa*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
( cd "$SRC" && git diff --quiet ) || { echo "FATAL: $SRC changed under the build"; exit 9; }
SHA=$(cd "$SRC" && git rev-parse --short HEAD)
J=${MT_JOBS:-8}
rm -f "$D/$TAG.rc"
sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" \
  > "$D/$TAG.out" 2> "$D/$TAG.err"
rc=$?
echo "$rc" > "$D/$TAG.rc"
echo "make all-gcc rc=$rc  (srcdir $SRC at $SHA anchor=$n)"
echo "error: lines: $(grep -c 'error:' "$D/$TAG.err" || true)"
echo "multiple definition: $(grep -c 'multiple definition' "$D/$TAG.err" || true)"
echo "undefined reference: $(grep -c 'undefined reference' "$D/$TAG.err" || true)"
ls -l "$D/gcc/cc1" 2>&1
