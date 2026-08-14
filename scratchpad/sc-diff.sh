#!/bin/sh
# STOCK CONTROL, part E -- diff a multi-target board against the stock board
# FOR THE SAME TARGET.
#
# The difference is the only thing this project owes.  A failure present in
# BOTH sums is what upstream GCC does to that target in a compile-only run with
# no target libgcc; it is not a multi-target defect and must not be counted as
# one.  A failure present ONLY in the multi-target sum is.
#
# THE JOIN IS A MULTISET JOIN, ON PURPOSE.  A .sum can carry the same test NAME
# more than once (torture variants that do not spell their options into the
# name, and repeated .exp files).  `sort -u' on names would silently drop those
# rows from one side and not the other, and the dropped rows would land in the
# ONLY-IN columns -- i.e. exactly the columns this script exists to report --
# as pure artefact.  So each row gets an occurrence index and the join is on
# (name, index).
#
# NOTHING IS SUBTRACTED ANYWHERE.  UNRESOLVED and ERROR are their own rows;
# KILLED is counted separately by taa-mtscore.sh and never enters here.
#
# usage: sc-diff.sh <mt-sum> <stock-sum> <label>
set -u
# `join' REQUIRES ITS INPUTS IN THE COLLATING ORDER IT USES, and the default
# locale is not C: `sort' put `outputs-10' where `join' did not expect it and
# join printed "input is not in sorted order" ON STDERR while still emitting a
# TRUNCATED table on stdout.  A silently short per-directory table is exactly
# the kind of result that gets read as "those directories are clean".
export LC_ALL=C
MT=${1:?multi-target gcc.sum}
ST=${2:?stock gcc.sum}
LAB=${3:?label}

for f in "$MT" "$ST"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" \
    || { echo "FATAL: $f has no '=== gcc Summary' -- truncated run, not a board"; exit 9; }
done

# DIRECTORY OF A TEST NAME.  A .sum test name is `<path> <description>' and the
# DESCRIPTION CONTAINS SLASHES AND SPACES (`scan-assembler foo\tv5', `expected
# covered: {14(true) 15 18}').  Splitting the whole name on `/' therefore
# invents directories out of description text -- it did, and printed rows named
# `outputs-98 asm auxdump 2: outputs-2.su'.  Take the FIRST whitespace token,
# then at most two path components.
sc_dir () {
  sed -e 's/#[0-9]*$//' -e 's/[ 	].*//' \
  | awk -F/ '{ print (NF>1 ? $1"/"$2 : $1) }'
}

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

# verdict <TAB> name#occurrence
key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' | sort -t"$(printf '\t')" -k1,1
}
key "$MT" > "$TD/mt"
key "$ST" > "$TD/st"

nmt=$(wc -l < "$TD/mt"); nst=$(wc -l < "$TD/st")
[ "$nmt" -gt 1000 ] && [ "$nst" -gt 1000 ] \
  || { echo "FATAL: $nmt / $nst rows -- one of these is not a full run"; exit 9; }

echo "===================================================================="
echo "== $LAB"
echo "==   multi-target: $MT   ($nmt results)"
echo "==   stock:        $ST   ($nst results)"
echo "===================================================================="
echo
echo "-- TOTALS (no floor subtracted anywhere)"
printf '%-12s %10s %10s %10s\n' VERDICT MULTI-TARGET STOCK DELTA
for v in PASS FAIL XPASS XFAIL UNSUPPORTED UNRESOLVED ERROR; do
  a=$(awk -F'\t' -v v="$v" '$2==v' "$TD/mt" | wc -l)
  b=$(awk -F'\t' -v v="$v" '$2==v' "$TD/st" | wc -l)
  printf '%-12s %10s %10s %+10d\n' "$v" "$a" "$b" "$((a-b))"
done

echo
echo "-- THE TRANSITION MATRIX over tests present on BOTH sides"
echo "   (rows = stock verdict, cols = multi-target verdict)"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$TD/st" "$TD/mt" > "$TD/j"
njoin=$(wc -l < "$TD/j")
echo "   joined rows: $njoin"
[ "$njoin" -gt 1000 ] || { echo "FATAL: only $njoin rows joined; the two runs are not comparable"; exit 9; }
awk -F'\t' '{ c[$2"\t"$3]++ }
  END { for (k in c) printf "%8d  stock %-12s -> mt %s\n", c[k], substr(k,1,index(k,"\t")-1), substr(k,index(k,"\t")+1) }' \
  "$TD/j" | sort -rn

echo
echo "-- REGRESSIONS: stock PASS -> multi-target NOT PASS.  THIS IS THE DEBT."
awk -F'\t' '$2=="PASS" && $3!="PASS" {print $3"\t"$1}' "$TD/j" > "$TD/reg"
echo "   count: $(wc -l < "$TD/reg")"
echo "   by multi-target verdict:"
awk -F'\t' '{c[$1]++} END {for (k in c) printf "%8d  -> %s\n", c[k], k}' "$TD/reg" | sort -rn
echo "   by test directory (top 25):"
awk -F'\t' '{ print $2 }' "$TD/reg" | sc_dir | sort | uniq -c | sort -rn | head -25
echo "   20 named regressions (the work queue, verbatim):"
awk -F'\t' '{sub(/#[0-9]+$/,"",$2); printf "     %-11s %s\n", $1, $2}' "$TD/reg" | sort | head -20

echo
echo "-- FIXED BY NOTHING: multi-target PASS where stock does NOT pass"
echo "   (not a claim of improvement -- read it as a check that the two runs"
echo "    are not one run compared with itself)"
awk -F'\t' '$3=="PASS" && $2!="PASS"' "$TD/j" | wc -l

echo
echo "-- FAILING ON BOTH SIDES: upstream's own behaviour, NOT this project's debt"
awk -F'\t' '$2=="FAIL" && $3=="FAIL"' "$TD/j" | wc -l

echo
echo "-- PER TEST DIRECTORY: FAIL counts, both sides"
dirof () {
  awk -F'\t' -v want="$1" '$2==want {print $1}' "$2" | sc_dir | sort | uniq -c \
  | awk '{printf "%s\t%d\n", $2, $1}' | sort
}
dirof FAIL "$TD/mt" > "$TD/dmt"
dirof FAIL "$TD/st" > "$TD/dst"
dirof PASS "$TD/mt" > "$TD/pmt"
dirof PASS "$TD/st" > "$TD/pst"
printf '%-34s %9s %9s %9s   %9s %9s %9s\n' DIRECTORY FAIL_MT FAIL_ST FAIL_D PASS_MT PASS_ST PASS_D
join -t"$(printf '\t')" -a1 -a2 -e0 -o 0,1.2,2.2 "$TD/dmt" "$TD/dst" > "$TD/dj"
join -t"$(printf '\t')" -a1 -a2 -e0 -o 0,1.2,2.2 "$TD/pmt" "$TD/pst" > "$TD/pj"
join -t"$(printf '\t')" -a1 -a2 -e0 -o 0,1.2,1.3,2.2,2.3 "$TD/dj" "$TD/pj" \
 | awk -F'\t' '{printf "%-34s %9d %9d %9d   %9d %9d %9d\n", $1,$2,$3,$2-$3,$4,$5,$4-$5}' \
 | sort -k4,4nr | awk '$2+$3+$5+$6 >= 20'

echo
echo "-- ONLY-IN rows (a test name+occurrence one side produced and the other"
echo "   did not).  Large numbers here mean the two runs did not attempt the"
echo "   same work, and the totals above must be read with that in mind."
cut -f1 "$TD/mt" | sort > "$TD/nmt"
cut -f1 "$TD/st" | sort > "$TD/nst"
echo "   only multi-target: $(comm -23 "$TD/nmt" "$TD/nst" | wc -l)"
echo "   only stock:        $(comm -13 "$TD/nmt" "$TD/nst" | wc -l)"
echo "   top 15 only-in-stock names:"
comm -13 "$TD/nmt" "$TD/nst" | sc_dir | sort | uniq -c | sort -rn | head -15
echo "   top 15 only-in-multi-target names:"
comm -23 "$TD/nmt" "$TD/nst" | sc_dir | sort | uniq -c | sort -rn | head -15
