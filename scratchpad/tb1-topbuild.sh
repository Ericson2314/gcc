#!/bin/sh
# #171 -- TOP-LEVEL `all-gcc' in a build dir, with the same snapshot assertions
# and the same `.rc' stamp as t171-build.sh.
#
# A SEPARATE SCRIPT BECAUSE t171-build.sh's `if [ -d $D/gcc ]' TEST IS WRONG
# AND IT COST A BUILD.  It runs `make cc1' inside $D/gcc when that directory
# exists, which skips the top level -- so libiberty.a, libcpp.a,
# libdecnumber.a and libbacktrace.a are never built and the link fails with
# `No rule to make target ../libcpp/libcpp.a'.  That reads as a broken tree.
# It is not: it is `configure-gcc' having been run for another reason (here,
# t171-gen.sh) so that the directory exists before anything in it does.
# Inherited from t165-build.sh; recorded rather than quietly patched, because
# the same trap is in every t<NNN>-build.sh on the branch.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-agent-aab545de8b02de843*) ;;
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
echo "multiple definition: $(grep -c 'multiple definition' "$D/make-top.err" || true)"
echo "undefined reference: $(grep -c 'undefined reference' "$D/make-top.err" || true)"
