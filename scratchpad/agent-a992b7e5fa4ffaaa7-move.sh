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
# THE FOUR ROWS HAVE THREE DIFFERENT BASELINES, AND THE SPANS ARE NOT EQUAL.
# Quoting one number for all four would be wrong in both directions.  The
# commit chain is `e3fac057ae4' -> `d5ad77b33b3' -> HEAD `e1f0cad1c2c'
# (asserted with merge-base, not assumed), and what was scored where is:
#
#   e3fac057ae4  A01E6C604F26604A7-BOARD   all four   debts 67/513/2074/207
#   d5ad77b33b3  A018835BBCFAD2E28-BOARD   riscv64 (debt 772, supersedes the
#                2,074) and x86_64 (162171/16295, byte-for-byte INERT), and
#                **aarch64 and s390x NOT AT ALL** -- that board says so itself
#                and files it as handover item 6.
#
# So `riscv64' and `x86_64' get the TIGHT baseline `d5ad77b33b3', and their
# span is exactly the brief's four causes.  `aarch64' and `s390x' can only get
# `e3fac057ae4', and their span therefore ALSO contains the auto-inc,
# alignment and `PROMOTE_MODE' work -- which is not a detail: `PROMOTE_MODE'
# alone moved 1,116 results on riscv64, `aarch64.h' is one of its definers,
# and `bd6f4dbe3ae' is titled *"the eight `USE_*' macros too, or aarch64
# regresses"*.  **Movement on those two rows is therefore NOT attributable to
# the brief's four causes**, and this script prints the span with every row so
# that it cannot be.
#
# Using the A01E riscv64 sum here would likewise manufacture ~1,300 of
# "movement" that is really a fix already measured and reported by someone
# else.
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
 "x86_64-pc-linux-gnu|/tmp/w-a018835bbcfad2e28/tip-x86_64.sum|d5ad77b33b3 (span = the brief's 4 causes)" \
 "aarch64-unknown-linux-gnu|$P/aarch64-unknown-linux-gnu.sum|e3fac057ae4 (span ALSO includes auto-inc/align/PROMOTE_MODE -- NEVER SCORED on this target)" \
 "riscv64-unknown-linux-gnu|/tmp/w-a018835bbcfad2e28/tip-riscv64.sum|d5ad77b33b3 (span = the brief's 4 causes)" \
 "s390x-ibm-linux-gnu|$P/s390x-ibm-linux-gnu.sum|e3fac057ae4 (span ALSO includes auto-inc/align/PROMOTE_MODE -- NEVER SCORED on this target)"

for spec in "$@"; do
  T=${spec%%|*}; rest=${spec#*|}; OLD=${rest%%|*}; SHA=${rest#*|}
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
