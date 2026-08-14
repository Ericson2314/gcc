#!/bin/sh
# #150 -- the stock-compare acceptance bar against genuine upstream GCC.
#
# IN is made ABSOLUTE here, per stock-compare.sh's own recorded false green:
# a relative IN produced no .s files at all and the negative control still
# printed "ok, differs", because `cmp -s' on two NONEXISTENT files exits
# non-zero, which read as success.
set -u
S=$(cd "$(dirname "$0")" && pwd)
MT=${1:-/tmp/b-ad0e44242408b7fde-2}
case "$MT" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $MT is not named for this worktree"; exit 9 ;;
esac
IN="$S/big.c"
[ -s "$IN" ] || { echo "FATAL: $IN missing or empty"; exit 9; }
MT="$MT" IN="$IN" OUT=/tmp/stockcmp-ad0e bash "$S/stock-compare.sh"
