#!/bin/sh
# mt-debt-rank.sh -- the RANKED RESIDUAL for one target: where the debt
# (`stock PASS -> multi-target NOT PASS') actually is, at a directory depth
# deep enough to be a work item.
#
# WHY IT IS NOT `sc-diff.sh'.  sc-diff.sh cuts a test name to TWO path
# components, which is right for a board-level view and useless for aarch64,
# where 96% of the debt lives under `gcc.target/aarch64' and the question is
# WHICH of `sve/acle', `sve2/acle', `sme/acle-asm', `simd', ... it is in.  The
# depth is a parameter here for that reason.
#
# IT ALSO PRINTS STOCK'S FIGURE BESIDE EACH ROW, which is the whole point: a
# directory where multi-target fails 500 and stock fails 500 is not a work
# item, and a directory where stock fails ZERO is.  A ranking without the
# control column has been wrong on this branch twice -- once by crediting a
# directory's whole debt to its top diagnostic (`extra_headers', over-attributed
# by 80,264) and once by ranking a HARNESS defect as a compiler one
# (`gcc.c-torture/compile', which was the host assembler).
#
# THE NAME OF A TEST IS `<path> <description>' AND THE DESCRIPTION CONTAINS
# SLASHES AND SPACES (`scan-assembler foo\tv5'), so the path is the FIRST
# WHITESPACE TOKEN only.  Splitting the whole name invents directories out of
# description text; sc-diff.sh's comment records that it did exactly that.
#
# usage: mt-debt-rank.sh <mt-sum> <stock-sum> <depth> [<top-n>]
set -u
export LC_ALL=C
MT=${1:?multi-target gcc.sum}
ST=${2:?stock gcc.sum}
DEPTH=${3:-3}
TOPN=${4:-25}

for f in "$MT" "$ST"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" \
    || { echo "FATAL: $f has no '=== gcc Summary' -- truncated run"; exit 9; }
done

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' \
  | sort -t"$(printf '\t')" -k1,1
}
key "$MT" > "$TD/mt"
key "$ST" > "$TD/st"

dirof () {
  sed -e 's/#[0-9]*$//' -e 's/[ 	].*//' \
  | awk -F/ -v d="$DEPTH" '{ n = (NF < d ? NF : d); s = $1;
      for (i = 2; i <= n; i++) s = s "/" $i; print s }'
}

join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$TD/st" "$TD/mt" > "$TD/j"
nj=$(wc -l < "$TD/j")
[ "$nj" -gt 1000 ] || { echo "FATAL: only $nj rows joined; not comparable"; exit 9; }

# THE DEBT, and the NON-VACUITY arm on it.  A zero debt is a real possible
# answer (parity), so it must not be silently indistinguishable from a broken
# join -- the join count above is what makes the zero meaningful.
awk -F'\t' '$2=="PASS" && $3!="PASS" {print $1}' "$TD/j" | dirof | sort | uniq -c | sort -rn \
  > "$TD/debt"
echo "-- joined rows: $nj    total debt: $(awk '{s+=$1} END {print s+0}' "$TD/debt")"
echo

# stock's own FAIL count per directory, so no row is read without its control.
awk -F'\t' '$2=="FAIL" {print $1}' "$TD/st" | dirof | sort | uniq -c \
  | awk '{printf "%s\t%d\n", $2, $1}' | sort > "$TD/stfail"
awk -F'\t' '$2=="PASS" {print $1}' "$TD/st" | dirof | sort | uniq -c \
  | awk '{printf "%s\t%d\n", $2, $1}' | sort > "$TD/stpass"

printf '%-46s %9s %9s %9s\n' DIRECTORY DEBT STOCK_FAIL STOCK_PASS
awk '{printf "%s\t%d\n", $2, $1}' "$TD/debt" | sort > "$TD/d"
join -t"$(printf '\t')" -a1 -e0 -o 0,1.2,2.2 "$TD/d" "$TD/stfail" > "$TD/d1"
join -t"$(printf '\t')" -a1 -e0 -o 0,1.2,1.3,2.2 "$TD/d1" "$TD/stpass" \
 | sort -t"$(printf '\t')" -k2,2nr \
 | head -"$TOPN" \
 | awk -F'\t' '{printf "%-46s %9d %9d %9d\n", $1, $2, $3, $4}'
