#!/bin/sh
# #174 -- the SMOKE arm: two bases, from an immutable snapshot.  Cheap and
# loud; the 47-back-end arm is what the deps-diff is taken from.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snapshot}
D=${2:?build dir}
SRC=$SNAP WANT_ANCHOR=${WANT_ANCHOR:?} sh "$S/t174-conf.sh" "$D" \
  x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu
WANT_ANCHOR=${WANT_ANCHOR} sh "$S/t174-topbuild.sh" "$D"
