#!/bin/sh
# MOVEMENT, per target, against the PREVIOUS board's preserved sums.
#
# WHY THIS IS A SEPARATE ARM FROM `agent-a01e6c604f26604a7-score.sh'.  That
# script scores the DEBT (multi-target vs STOCK).  This one scores MOVEMENT
# (multi-target vs multi-target at the previous board's commit), and the
# standing rule is that **columns cannot distinguish a fix from a regression**
# -- FAIL once rose +38,303 while 87,963 tests went UNRESOLVED->PASS.  So the
# per-name and CARDINALITY arms of mt-namediff.sh are the authority for every
# claim of movement here, and the totals are printed only for reconciliation.
#
# THE riscv64 BASELINE IS NOT THE SAME BOARD AS THE OTHER THREE, and quoting
# one number for all four would be wrong.  x86_64/aarch64/s390x were last
# scored at `e3fac057ae4' (A01E6C604F26604A7-BOARD, debts 67/513/207); riscv64
# was scored LATER and alone at `d5ad77b33b3' (A018835BBCFAD2E28-BOARD, debt
# 772, PASS 268932 / FAIL 16762), which supersedes that board's 2,074.  Using
# the A01E riscv64 sum here would manufacture ~1,300 of movement that is really
# a fix already measured and reported by someone else.
#
# Each baseline is re-read and its summary marker asserted before use: a
# truncated .sum greps clean and would land its missing rows in the
# only-in-new column, i.e. exactly the column this script exists to report.
#
# usage: agent-a992b7e5fa4ffaaa7-move.sh <dir-with-the-four-preserved-sums>
set -u
export LC_ALL=C
L=${1:?directory holding <triple>.sum}
S=$(cd "$(dirname "$0")" && pwd)
P=/tmp/board-agent-a01e6c604f26604a7

set -- \
 "x86_64-pc-linux-gnu|$P/x86_64-pc-linux-gnu.sum|e3fac057ae4" \
 "aarch64-unknown-linux-gnu|$P/aarch64-unknown-linux-gnu.sum|e3fac057ae4" \
 "riscv64-unknown-linux-gnu|/tmp/w-a018835bbcfad2e28/tip-riscv64.sum|d5ad77b33b3" \
 "s390x-ibm-linux-gnu|$P/s390x-ibm-linux-gnu.sum|e3fac057ae4"

for spec in "$@"; do
  T=${spec%%|*}; rest=${spec#*|}; OLD=${rest%%|*}; SHA=${rest##*|}
  NEW="$L/$T.sum"
  echo
  echo "################################################################"
  echo "## $T   movement vs $SHA"
  echo "################################################################"
  # THE `.rc' STAMP, NOT THE SUMMARY MARKER.  A killed run produced a
  # complete-looking, internally consistent summary of a SIXTH of a run and
  # passed four of five guards.
  [ -f "$L/$T.rc" ] || { echo "REFUSED: no $L/$T.rc stamp -- not a scorable row"; continue; }
  echo "new-side check rc stamp: $(cat "$L/$T.rc")"
  [ -f "$OLD" ] || { echo "REFUSED: no baseline $OLD"; continue; }
  grep -q '=== gcc Summary' "$OLD" \
    || { echo "REFUSED: baseline $OLD truncated (no summary marker)"; continue; }
  printf 'baseline  PASS %s  FAIL %s   %s\n' \
    "$(grep -c '^PASS:' "$OLD")" "$(grep -c '^FAIL:' "$OLD")" "$OLD"
  printf 'new       PASS %s  FAIL %s   %s\n' \
    "$(grep -c '^PASS:' "$NEW")" "$(grep -c '^FAIL:' "$NEW")" "$NEW"
  sh "$S/mt-namediff.sh" "$OLD" "$NEW" "$T" > "$L/$T.namediff" 2>&1
  cat "$L/$T.namediff"
done
