#!/bin/sh
# Build at the TOP LEVEL (PRINCIPLES 5: `make' in the wrong directory gives
# `Nothing to be done' and exit 0 next to a stale binary).
#
# Asserts the build dir was configured from THIS tree, by reading the build's
# own testimony (config.log's absolute srcdir), before spending an hour on it.
#
# usage: gt-build.sh <builddir> [make args...]   default target: all-gcc
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}; shift
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D configured from '$got', not $SRC"; exit 9; }
echo "build dir $D confirmed configured from $SRC"
sh "$S/eb-shell.sh" "cd $D && make -j8 ${*:-all-gcc}"
echo "MAKE-RC=$?"
