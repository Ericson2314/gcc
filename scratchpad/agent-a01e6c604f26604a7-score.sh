#!/bin/sh
# Score the four-target board against the four intact stock controls, rank the
# residual per target, and size each target's top diagnostic at FILE level.
#
# The stock sums are re-read here, not quoted: the brief's 163816/16223,
# 344463/20443, 270248/15904 and 130895/15627 are claims to check.
#
# usage: agent-a01e6c604f26604a7-score.sh <dir-with-the-four-preserved-sums>
set -u
export LC_ALL=C
L=${1:?directory holding <triple>.sum}
S=$(cd "$(dirname "$0")" && pwd)

SX=/tmp/b-stock-agent-ab1900d5279ba137f-x86_64/gcc/testsuite.x86_64-pc-linux-gnu/gcc/gcc.sum
SA=/tmp/b-stock-agent-a3464debf6893de84-aarch64/gcc/testsuite.aarch64-unknown-linux-gnu/gcc/gcc.sum
SR=/tmp/b-stock-agent-ab1900d5279ba137f-riscv64/gcc/testsuite.riscv64-unknown-linux-gnu/gcc/gcc.sum
SS=/tmp/b-stock-agent-a3464debf6893de84-s390x/gcc/testsuite.s390x-ibm-linux-gnu/gcc/gcc.sum

set -- \
 "x86_64-pc-linux-gnu|$SX" \
 "aarch64-unknown-linux-gnu|$SA" \
 "riscv64-unknown-linux-gnu|$SR" \
 "s390x-ibm-linux-gnu|$SS"

for spec in "$@"; do
  T=${spec%%|*}; ST=${spec#*|}
  MT="$L/$T.sum"
  echo
  echo "################################################################"
  echo "## $T"
  echo "################################################################"
  [ -f "$L/$T.rc" ] || { echo "REFUSED: no $L/$T.rc stamp"; continue; }
  echo "check rc stamp: $(cat "$L/$T.rc")"
  sh "$S/sc-diff.sh" "$MT" "$ST" "$T" > "$L/$T.scdiff" 2>&1
  echo "-- sc-diff DEBT: $(sed -n '/THIS IS THE DEBT/,+1p' "$L/$T.scdiff" | sed -n 's/.*count: //p')"
  sed -n '/-- TOTALS/,/^$/p' "$L/$T.scdiff"
  sed -n '/THIS IS THE DEBT/,/named regressions/p' "$L/$T.scdiff"
  echo "-- RANKED RESIDUAL (depth 3):"
  sh "$S/mt-debt-rank.sh" "$MT" "$ST" 3 20 > "$L/$T.rank" 2>&1
  cat "$L/$T.rank"
  echo "-- TOP ICE DIAGNOSTICS in the multi-target sum:"
  grep '^FAIL:' "$MT" \
    | sed -n 's/.*internal compiler error: \(.*\))$/\1/p' \
    | sed 's/, at /, at /' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
done
