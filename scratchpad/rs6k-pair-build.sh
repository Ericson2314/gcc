#!/bin/sh
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=/tmp/b-a5fb19dec8368eaf6-pair
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D configured from '$got', not $SRC"; exit 9; }
sh "$S/eb-shell.sh" "cd $D && make -j8 all-gcc" > /tmp/rs6k-pair.out 2> /tmp/rs6k-pair.err
