#!/bin/sh
# Task #152: build all-gcc in the build dir configured by t152-conf.sh.
# usage: t152-build.sh <builddir> [target]
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
T=${2:-all-gcc}
# The build dir's own testimony about which srcdir configured it, per
# PRINCIPLES section 4 -- independent of this script.
grep -q '/tmp/snap-a2ee9df2/configure' "$D/config.log" \
  || { echo "FATAL: $D was not configured from /tmp/snap-a2ee9df2"; exit 9; }
grep -c MULTI_TARGET /tmp/snap-a2ee9df2/gcc/Makefile.in | grep -qx 48 \
  || { echo "FATAL: snapshot anchor is not 48"; exit 9; }
exec sh "$S/eb-shell.sh" "cd $D && make -j8 $T"
