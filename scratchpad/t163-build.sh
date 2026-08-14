#!/bin/sh
# #163 -- build the four-back-end tree.
#
# PRINCIPLES section 5: every t<NNN>-build.sh on this branch has the same wrong
# test -- it runs `make cc1' inside $D/gcc *if that directory exists*, and that
# directory exists as soon as anything has run configure-gcc.  The test here is
# "has libcpp.a been built", never "does the directory exist".
#
# PRINCIPLES section 4: write <tag>.rc ONLY after make returns, and the scorer
# must refuse any log without that stamp.  A log being written looks exactly
# like a log that finished.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:-t163}
J=${J:-8}

[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC stamp"; exit 9; }
SNAP=$(cat "$D/MY-SRC")
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:-55}" ] || { echo "FATAL: $SNAP anchor=$n"; exit 9; }

rm -f "$D/$TAG.rc"
if [ -f "$D/libcpp/libcpp.a" ]; then
  echo "libcpp.a present -- incremental make in $D/gcc"
  sh "$S/eb-shell.sh" "cd $D/gcc && make -j$J cc1" > "$D/$TAG.out" 2> "$D/$TAG.err"
else
  echo "no libcpp.a -- top-level make all-gcc in $D"
  sh "$S/eb-shell.sh" "cd $D && make -j$J all-gcc" > "$D/$TAG.out" 2> "$D/$TAG.err"
fi
rc=$?
# The stamp is written ONLY here, after make returned.
echo "$rc" > "$D/$TAG.rc"
echo "make rc=$rc  (stamped $D/$TAG.rc)"
tail -5 "$D/$TAG.err"
