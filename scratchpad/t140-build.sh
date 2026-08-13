#!/bin/sh
# #140 -- build the bars in a build dir this worktree configured.
# usage: t140-build.sh [builddir] [targets...]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b140}
shift || true
T=${*:-multi-target-objs cc1 lto1}

# PRINCIPLES section 4: assert WHICH TREE this build dir was configured from,
# by the build's own testimony rather than by assuming $0's location.
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] \
  || { echo "FATAL: $D was configured from '$got', not $SRC"; exit 9; }
echo "build dir $D configured from $SRC OK"

# `cc1'/`multi-target-objs' build in $D/gcc; at the top level you get
# `No rule to make target' or, worse, `Nothing to be done' next to a stale
# binary (PRINCIPLES section 5).  But $D/gcc does not exist until the top
# level has configured it, so bootstrap it there once.
# ...and $D/gcc cannot be entered until the top level has configured it AND
# built libiberty and the build tools it needs, so bootstrap there once.
if [ ! -x "$D/gcc/cc1" ]; then
  sh "$S/eb-shell.sh" "cd $D && make -j8 all-gcc" || exit 1
fi
exec sh "$S/eb-shell.sh" "cd $D/gcc && make -j8 $T"
