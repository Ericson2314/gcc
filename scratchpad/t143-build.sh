#!/bin/sh
# Build, and STAMP THE EXIT (PRINCIPLES section 4): `<tag>.rc' is written only
# after make returns, and every scorer must REFUSE a log lacking that stamp.
# A log being written looks exactly like a log that finished -- a partial log
# is non-empty, contains real compile lines, and greps clean.
#
# usage: t143-build.sh <builddir> <tag> [make args...]
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
shift 2
# WHERE to run make.  gcc/ targets such as `multi-target-objs' need the build
# machine's libiberty and libcpp, which live in ../build-*/ and are built by
# TOP-LEVEL rules.  Running make inside gcc/ gets
#   No rule to make target '../build-x86_64-pc-linux-gnu/libiberty/libiberty.a'
# and then skips everything downstream -- which under -k is silence, not a
# diagnostic.  Set MT_IN_GCC=1 only once those prerequisites already exist.
WD=$D
[ "${MT_IN_GCC:-0}" = 1 ] && WD=$D/gcc
# The top-level configure writes only the top Makefile; gcc/ appears when make
# descends.  Create it here rather than letting the scorer meet a missing dir.
if [ ! -f "$D/gcc/Makefile" ]; then
  echo "configuring gcc/ subdir ..."
  sh "$S/eb-shell.sh" "cd $D && make configure-gcc" > "$D/cfggcc.out" 2> "$D/cfggcc.err" \
    || { echo "FATAL: make configure-gcc failed"; tail -5 "$D/cfggcc.err"; exit 9; }
fi
[ -f "$D/gcc/Makefile" ] || { echo "FATAL: $D/gcc/Makefile still absent"; exit 9; }
# The build's own testimony about which tree it was configured from.
src=$(sed -n 's/.*running configure, //p;' "$D/config.log" | head -1)
grep -m1 -o '/tmp/snap-[a-z0-9]*' "$D/config.log" \
  || { echo "FATAL: $D was not configured from a /tmp/snap-* immutable snapshot"; exit 9; }

rm -f "$D/$TAG.rc" "$D/$TAG.out" "$D/$TAG.err"
# `cmd || true; rc=$?' CAPTURES THE STATUS OF `true' AND IS ALWAYS 0.  That bug
# was in this script and produced a stamped rc=0 for a make that had printed
# "Target 'multi-target-objs' not remade because of errors" -- a false green of
# exactly the shape PRINCIPLES section 4 exists to prevent.  Set +e around the
# call and read $? immediately instead.
set +e
sh "$S/eb-shell.sh" "cd $WD && make -k -j8 $*" \
  > "$D/$TAG.out" 2> "$D/$TAG.err"
rc=$?
set -e
# WRITTEN ONLY AFTER make RETURNS.
echo "$rc" > "$D/$TAG.rc"
echo "make $* rc=$rc  (stamped $D/$TAG.rc)"
# make -k can exit 0 having skipped targets, so the exit status is not the
# whole verdict: report make's own failure lines too.
echo "-- make failure lines:"
grep -cE "^make.*(\*\*\*|not remade because of errors)" "$D/$TAG.err" || true
grep -hE "not remade because of errors" "$D/$TAG.err" || true
wc -l "$D/$TAG.out" "$D/$TAG.err"
