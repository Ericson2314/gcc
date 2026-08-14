#!/bin/sh
# #121 -- build all-gcc in the three-base build dir, asserting the build dir was
# configured from THIS worktree (PRINCIPLES section 5: /tmp/b<task> is not your
# own; config.log records the absolute srcdir configure ran from, and that is
# the only instrument independent of this script).
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b-abeb4d62}
J=${J:-8}

grep -q "srcdir=$SRC\$\|$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name srcdir $SRC"; exit 9; }
echo "build dir $D was configured from $SRC OK"

# From the TOP LEVEL: a freshly configured tree has no $D/gcc yet, and `cd
# $D/gcc' fails with "No such file or directory" -- which, piped into `tail',
# is invisible and the pipeline reports 0 (PRINCIPLES section 7).
sh "$S/eb-shell.sh" "cd $D && make -j$J all-gcc"
test -x "$D/gcc/cc1" || { echo "FATAL: no $D/gcc/cc1 after all-gcc"; exit 9; }
echo "cc1 built OK"
