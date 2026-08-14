#!/bin/sh
# #136 -- build in a t136-conf.sh build dir.  $1 = build dir, $2 = make target.
# The `.rc' STAMP is written only after make returns: a log being written looks
# exactly like a log that finished (PRINCIPLES 4).
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
T=${2:-cc1}
case "$D" in
  */b-a5cf4*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
SHA=$(cat "$SRC/SNAP-SHA")

J=${MT_JOBS:-8}
rm -f "$D/make-$T.rc"
if [ -d "$D/gcc" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -k -j$J $T" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
else
  sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
fi
rc=$?
echo "$rc" > "$D/make-$T.rc"
echo "make $T rc=$rc  (snapshot $SRC at $SHA)"
echo "error: lines: $(grep -c 'error:' "$D/make-$T.err")"
echo "multiple definition: $(grep -c 'multiple definition' "$D/make-$T.err")"
echo "undefined reference: $(grep -c 'undefined reference' "$D/make-$T.err")"
