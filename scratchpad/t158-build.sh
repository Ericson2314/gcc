#!/bin/sh
# #158 -- build the 48-back-end tree with -k and keep the full log.
#
# A 48-back-end build does NOT produce a linked cc1 (28 failing targets are
# pre-existing), so this is an OBJECT-LEVEL census only.  Do not claim a
# runtime bar from this build dir.
#
# usage: t158-build.sh <builddir> <tag>
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
J=${J:-8}   # -j16 has failed with NO diagnostic under memory pressure

[ -d "$D/gcc" ] || sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" >/dev/null 2>&1 || true
sh "$S/eb-shell.sh" "cd $D && make -k -j$J all-gcc" > "$D/build-$TAG.out" 2> "$D/build-$TAG.err"
echo "make rc=$? (under -k, rc is not the measurement)"
wc -l "$D/build-$TAG.out" "$D/build-$TAG.err"
