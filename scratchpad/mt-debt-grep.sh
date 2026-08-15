#!/bin/sh
# mt-debt-grep.sh -- how many DEBT results match a pattern, and what they say.
#
# The companion to mt-debt-rank.sh, for the case its per-directory view cannot
# answer: a FAMILY of test files spread across one directory (`mv-*.c',
# `fmv-*.c' -- function multiversioning) is 20 rows of 10 in the ranking and
# one work item in reality.  Ranking by directory splits it; ranking by file
# buries it.
#
# NON-VACUITY IS MANDATORY HERE and is the whole reason this is a script.  A
# pattern that matches nothing prints `0', which is exactly what a converted
# tree prints, and this project has lost six sessions to that shape.  So the
# total debt is printed FIRST, unconditionally: a `0' beside a non-zero total
# is a real zero, and a `0' beside a `0' total means the join is broken.
#
# usage: mt-debt-grep.sh <mt-sum> <stock-sum> <egrep-pattern> [<n-samples>]
set -u
export LC_ALL=C
MT=${1:?multi-target gcc.sum}
ST=${2:?stock gcc.sum}
PAT=${3:?pattern}
N=${4:-8}

for f in "$MT" "$ST"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" || { echo "FATAL: $f truncated"; exit 9; }
done

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0
key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' \
  | sort -t"$(printf '\t')" -k1,1
}
key "$MT" > "$TD/mt"; key "$ST" > "$TD/st"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$TD/st" "$TD/mt" > "$TD/j"
awk -F'\t' '$2=="PASS" && $3!="PASS" {print $3"\t"$1}' "$TD/j" | sed 's/#[0-9]*$//' > "$TD/debt"

tot=$(wc -l < "$TD/debt")
echo "-- total debt on this target: $tot   (printed FIRST: a 0 below beside a"
echo "   non-zero total is a real zero; a 0 beside a 0 total means the join broke)"
[ "$tot" -gt 0 ] || { echo "FATAL: total debt is 0 -- refusing to report a match count"; exit 9; }
hit=$(grep -cE "$PAT" "$TD/debt" || true)
echo "-- debt matching /$PAT/: $hit"
echo "-- $N samples:"
grep -E "$PAT" "$TD/debt" | head -"$N" | sed 's/^/    /'
