#!/bin/sh
# #140 -- stock-compare against THIS worktree's build dir, with an ABSOLUTE
# IN (a relative one produced a false green once; see stock-compare.sh).
S=$(cd "$(dirname "$0")" && pwd)
IN="$S/big.c" OUT=/tmp/stockcmp140 MT=${1:-/tmp/b140} ST=/tmp/b-stock \
  exec bash "$S/stock-compare.sh"
