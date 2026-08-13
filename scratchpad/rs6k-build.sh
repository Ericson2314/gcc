#!/bin/sh
# rs6000 grind -- build in a dir this worktree configured.  Asserts the
# build's own testimony about which srcdir it came from (PRINCIPLES 4).
# usage: rs6k-build.sh <outstem> [targets...]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=/tmp/b-a5fb19dec8368eaf6
STEM=${1:?output stem}
shift || true
T=${*:-multi-target-objs cc1 lto1}

got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] \
  || { echo "FATAL: $D was configured from '$got', not $SRC"; exit 9; }
echo "build dir $D configured from $SRC OK"

sh "$S/eb-shell.sh" "cd $D/gcc && make -j8 -k $T" > "$STEM.out" 2> "$STEM.err"
