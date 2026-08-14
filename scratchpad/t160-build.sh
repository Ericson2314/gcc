#!/bin/sh
# #160 -- build a base set with -k, keep the full log, and STAMP THE EXIT.
#
# PRINCIPLES section 4: "a log being written looks exactly like a log that
# finished".  <tag>.rc is written ONLY after make returns, and every scorer in
# this task refuses a log with no stamp.  Under -k the rc itself is not the
# measurement; its EXISTENCE is.
#
# usage: t160-build.sh <builddir> <tag> [target]
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
T=${3:-all-gcc}
J=${J:-8}   # -j16 has failed with NO diagnostic under memory pressure

rm -f "$D/build-$TAG.rc"
rc=0
sh "$S/eb-shell.sh" "cd $D && make -k -j$J $T" > "$D/build-$TAG.out" 2> "$D/build-$TAG.err" || rc=$?
echo "$rc" > "$D/build-$TAG.rc"
echo "make rc=$rc (under -k, rc is not the measurement; the .rc stamp is)"
wc -l "$D/build-$TAG.out" "$D/build-$TAG.err"
