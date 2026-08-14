#!/bin/sh
# UR task -- build the multi-back-end tree with -k, keep the full log, and
# STAMP THE EXIT.
#
# PRINCIPLES section 4: "A LOG BEING WRITTEN LOOKS EXACTLY LIKE A LOG THAT
# FINISHED".  The scorer (ur-score.sh) REFUSES any log lacking <tag>.rc, so an
# unfinished build is a hard failure by name rather than a smaller number.
#
# usage: ur-build.sh <builddir> <tag>
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
J=${J:-8}   # -j16 has failed with NO diagnostic under memory pressure

rm -f "$D/build-$TAG.rc"
sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" \
  > "$D/build-$TAG.out" 2> "$D/build-$TAG.err" || true
rc=$?
# The stamp is written ONLY after make has returned.
echo "$rc" > "$D/build-$TAG.rc"
echo "make returned rc=$rc (under -k, rc is not the measurement)"
wc -l "$D/build-$TAG.out" "$D/build-$TAG.err"
