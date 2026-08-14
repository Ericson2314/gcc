#!/bin/sh
# #174 -- configure + build one 47-back-end arm, from an immutable snapshot.
# usage: t174-go-base.sh <snapshot> <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snapshot}
D=${2:?build dir}
LIST=$(grep -v '^#' "$S/backends-47.txt" | grep . | tr '\n' ',' | sed 's/,$//')
n=$(printf '%s' "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: $n triples, expected 47"; exit 9; }
SRC=$SNAP WANT_ANCHOR=${WANT_ANCHOR:?} sh "$S/t174-conf.sh" "$D" "$LIST"
WANT_ANCHOR=${WANT_ANCHOR} sh "$S/t174-topbuild.sh" "$D"
