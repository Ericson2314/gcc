#!/bin/sh
# Size a cause TWO ways, because they answer different questions and this
# project has confused them before.
#
#   BACKENDS  how many back ends carry it at all -- the ranking that matters
#             here, because every fix on this branch has been one name with
#             several authorities.
#   ROWS      how many FAIL rows it accounts for, per back end.
#
# ROWS IS NOT A DEBT AND IS NOT COMPARABLE WITH ONE.  There is no stock
# control for the newly-scored back ends, so a row count is raw FAIL, not
# `stock PASS -> multi-target NOT PASS'.  And an ICEing test contributes an ICE
# row AND a `(test for excess errors)' sibling, so rows overcount tests --
# `AB1900D5279BA137F-BOARD.md` 3 records that arithmetic and the zero it
# produces if you join the two naively.  Use ROWS to rank, never to subtract.
set -u
OUT=${1:?artefact dir}
PAT=${2:?cause substring}
n=$(ls "$OUT"/*.gcc.sum 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "FATAL: no *.gcc.sum in $OUT"; exit 9; }
tot=0; nbe=0
for f in "$OUT"/*.gcc.sum; do
  T=$(basename "$f" .gcc.sum)
  c=$(grep -c "$PAT" "$f")
  [ "$c" = 0 ] && continue
  printf '  %-28s %s\n' "$T" "$c"
  tot=$((tot+c)); nbe=$((nbe+1))
done
echo "  -- $PAT: $nbe back ends, $tot rows (of $n scored)"
[ "$nbe" -gt 0 ] || echo "  -- ZERO: either absent, or the pattern does not match the .sum text"
