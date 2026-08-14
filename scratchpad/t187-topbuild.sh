#!/bin/sh
# #187 -- TOP-LEVEL `all-gcc' in a build dir, with the snapshot assertions and
# the `.rc' exit stamp (a log being written looks exactly like a log that
# finished -- PRINCIPLES 4).  Copy of t176-topbuild.sh with this worktree's
# build-dir assertion.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-agent-a85d505af66ec2223*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name $SRC"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
[ -f "$SRC/SNAP-SHA" ] || { echo "FATAL: $SRC has no SNAP-SHA"; exit 9; }
[ ! -w "$SRC/gcc/Makefile.in" ] || { echo "FATAL: $SRC is writable"; exit 9; }
SHA=$(cat "$SRC/SNAP-SHA")
J=${MT_JOBS:-8}
rm -f "$D/make-top.rc"
sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" \
  > "$D/make-top.out" 2> "$D/make-top.err"
rc=$?
echo "$rc" > "$D/make-top.rc"
echo "make all-gcc rc=$rc  (srcdir $SRC at $SHA anchor=$n)"
echo "stderr lines: $(wc -l < "$D/make-top.err")"
echo "error: lines: $(grep -c 'error:' "$D/make-top.err" || true)"
