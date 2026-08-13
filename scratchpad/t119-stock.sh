#!/bin/sh
# #119 -- the stock comparison, with an ABSOLUTE IN (a relative one produced a
# documented false green) and this task's own build directory.
#
# stock-compare.sh hard-codes `-ftarget-config=specs-x86_64-pc-linux-gnu-config'
# relative to $MT/gcc.  The build no longer links the config file there -- doing
# so switches cc1's selftests on and they fail on the mode union (see
# Makefile.tpl) -- so this makes the link for the duration of the run and takes
# it away again.  Fails by name if the config is not there to link to, rather
# than letting stock-compare's own FATAL blame the wrong thing.
set -u
S=$(cd "$(dirname "$0")" && pwd)
MTD=${MT:-/tmp/b119}
CFG="$MTD/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config"
[ -f "$CFG" ] || { echo "FATAL: no $CFG; run t119-specs.sh first"; exit 9; }
LN="$MTD/gcc/specs-x86_64-pc-linux-gnu-config"
ln -sfn "$CFG" "$LN" || exit 9
trap 'rm -f "$LN"' 0
IN=$S/big.c MT=${MT:-/tmp/b119} ST=${ST:-/tmp/b-stock} OUT=${OUT:-/tmp/stockcmp119} \
  bash "$S/stock-compare.sh"
