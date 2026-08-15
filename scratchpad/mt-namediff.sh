#!/bin/sh
# mt-namediff.sh -- diff two multi-target runs of the SAME target BY TEST NAME,
# and specifically detect the transition COLUMN TOTALS CANNOT SEE.
#
# WHY THIS EXISTS AND WHY sc-diff.sh IS NOT IT.  sc-diff.sh compares
# multi-target against STOCK, to size the debt.  This compares multi-target
# against ITSELF at an earlier commit, to say what a fix did -- and those need
# different arms, because of #188:
#
#   A test that died as ONE `UNRESOLVED' becomes ~20 `scan-assembler' results
#   once it compiles.  If three of the twenty then fail, the FAIL column RISES
#   as the fix lands.
#
# Read as columns that is a regression.  Read as names it is 1 result becoming
# 20, of which 17 are new PASSes.  **A total cannot distinguish a fix from a
# regression when the fix changes how many results a test produces**, and on
# this branch the big fixes all do exactly that: they take a test from "did not
# compile" to "ran its checks".
#
# So the load-bearing arm here is not the transition matrix, it is
# CARDINALITY: results-per-test-FILE, old vs new.  That is the arm that says
# `gcc.target/aarch64/foo.c: 1 -> 23'.
#
# NOTHING IS SUBTRACTED, and KILLED is not read here at all (it is a log
# property; taa-mtscore.sh/mtscore.sh count it).
#
# usage: mt-namediff.sh <old.sum> <new.sum> <label>
set -u
# `join' needs its inputs in ITS collating order and the default locale is not
# C: sort once put `outputs-10' where join did not expect it, and join printed
# "input is not in sorted order" ON STDERR while still emitting a TRUNCATED
# table on stdout.  A silently short table reads as "those tests are clean".
export LC_ALL=C
OLD=${1:?old gcc.sum}
NEW=${2:?new gcc.sum}
LAB=${3:?label}

for f in "$OLD" "$NEW"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" \
    || { echo "FATAL: $f has no '=== gcc Summary' -- truncated run, not a board"; exit 9; }
done

# TEST FILE of a .sum line.  A name is `<path> <description>' and THE
# DESCRIPTION CONTAINS SLASHES AND SPACES (`scan-assembler foo\tv5',
# `expected covered: {14(true) 15 18}'), so splitting the whole name invents
# test files out of description text.  Take the first whitespace token only.
sc_file () { sed -e 's/[ 	].*//' ; }

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' \
  | sort -t"$(printf '\t')" -k1,1
}
key "$OLD" > "$TD/o"
key "$NEW" > "$TD/n"
no=$(wc -l < "$TD/o"); nn=$(wc -l < "$TD/n")
[ "$no" -gt 1000 ] && [ "$nn" -gt 1000 ] \
  || { echo "FATAL: $no / $nn rows -- one of these is not a full run"; exit 9; }

echo "===================================================================="
echo "== $LAB"
echo "==   old: $OLD  ($no results)"
echo "==   new: $NEW  ($nn results)"
echo "===================================================================="
echo
echo "-- TOTALS (nothing subtracted).  READ THESE WITH THE CARDINALITY"
echo "   SECTION BELOW: a rising FAIL column is not evidence of regression"
echo "   when the number of results per test has changed."
printf '%-12s %10s %10s %10s\n' VERDICT OLD NEW DELTA
for v in PASS FAIL XPASS XFAIL UNSUPPORTED UNRESOLVED ERROR; do
  a=$(awk -F'\t' -v v="$v" '$2==v' "$TD/o" | wc -l)
  b=$(awk -F'\t' -v v="$v" '$2==v' "$TD/n" | wc -l)
  printf '%-12s %10s %10s %+10d\n' "$v" "$a" "$b" "$((b-a))"
done

echo
echo "-- CARDINALITY: results per TEST FILE, old vs new.  THE #188 ARM."
cut -f1 "$TD/o" | sed 's/#[0-9]*$//' | sc_file | sort | uniq -c \
  | awk '{printf "%s\t%d\n", $2, $1}' | sort > "$TD/co"
cut -f1 "$TD/n" | sed 's/#[0-9]*$//' | sc_file | sort | uniq -c \
  | awk '{printf "%s\t%d\n", $2, $1}' | sort > "$TD/cn"
join -t"$(printf '\t')" -a1 -a2 -e0 -o 0,1.2,2.2 "$TD/co" "$TD/cn" > "$TD/cj"
grew=$(awk -F'\t' '$3>$2' "$TD/cj" | wc -l)
shrank=$(awk -F'\t' '$3<$2 && $3>0' "$TD/cj" | wc -l)
gone=$(awk -F'\t' '$3==0' "$TD/cj" | wc -l)
new=$(awk -F'\t' '$2==0' "$TD/cj" | wc -l)
addl=$(awk -F'\t' '$3>$2 {s+=$3-$2} END {print s+0}' "$TD/cj")
echo "   test files producing MORE results: $grew  (+$addl results in total)"
echo "   test files producing FEWER:        $shrank"
echo "   test files gone entirely:          $gone"
echo "   test files new entirely:           $new"
echo "   top 20 expansions (old -> new):"
awk -F'\t' '$3>$2 {printf "%8d -> %-8d %s\n", $2, $3, $1}' "$TD/cj" \
  | sort -k3,3nr | head -20
echo
echo "   *** $addl of the new run's results come from tests that produced"
echo "       FEWER results before.  Any column delta smaller than this is"
echo "       inside the noise this effect creates, in EITHER direction."

echo
echo "-- TRANSITIONS over (name, occurrence) present in BOTH runs"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$TD/o" "$TD/n" > "$TD/j"
nj=$(wc -l < "$TD/j")
echo "   joined rows: $nj"
[ "$nj" -gt 1000 ] || { echo "FATAL: only $nj rows joined; the runs are not comparable"; exit 9; }
awk -F'\t' '$2!=$3 { c[$2"\t"$3]++ }
  END { for (k in c) printf "%8d  %-12s -> %s\n", c[k],
          substr(k,1,index(k,"\t")-1), substr(k,index(k,"\t")+1) }' "$TD/j" \
  | sort -rn
same=$(awk -F'\t' '$2==$3' "$TD/j" | wc -l)
echo "   unchanged: $same"

echo
echo "-- REAL REGRESSIONS: PASS -> NOT PASS, by name.  This is the only"
echo "   column that means 'something got worse', and it is name-based so"
echo "   the cardinality effect above cannot manufacture it."
awk -F'\t' '$2=="PASS" && $3!="PASS" {print $3"\t"$1}' "$TD/j" > "$TD/reg"
echo "   count: $(wc -l < "$TD/reg")"
awk -F'\t' '{c[$1]++} END {for (k in c) printf "%8d  -> %s\n", c[k], k}' "$TD/reg" | sort -rn
echo "   by directory (top 15):"
awk -F'\t' '{print $2}' "$TD/reg" | sc_file | awk -F/ '{print (NF>1 ? $1"/"$2 : $1)}' \
  | sort | uniq -c | sort -rn | head -15
echo "   15 named, verbatim:"
awk -F'\t' '{sub(/#[0-9]+$/,"",$2); printf "     %-11s %s\n", $1, $2}' "$TD/reg" | sort | head -15

echo
echo "-- REAL PROGRESS: NOT PASS -> PASS, by name"
awk -F'\t' '$3=="PASS" && $2!="PASS"' "$TD/j" | wc -l
echo "   by directory (top 15):"
awk -F'\t' '$3=="PASS" && $2!="PASS" {print $1}' "$TD/j" | sed 's/#[0-9]*$//' | sc_file \
  | awk -F/ '{print (NF>1 ? $1"/"$2 : $1)}' | sort | uniq -c | sort -rn | head -15

echo
echo "-- NEW RESULTS: (name, occurrence) the new run produced and the old did"
echo "   not.  On this branch these are mostly tests that now COMPILE, so"
echo "   they are the fix's real yield -- and they are invisible to a"
echo "   transition matrix, which can only see rows present on both sides."
cut -f1 "$TD/o" | sort > "$TD/no"
cut -f1 "$TD/n" | sort > "$TD/nn"
comm -13 "$TD/no" "$TD/nn" > "$TD/onlynew"
comm -23 "$TD/no" "$TD/nn" > "$TD/onlyold"
echo "   only in new: $(wc -l < "$TD/onlynew")   only in old: $(wc -l < "$TD/onlyold")"
echo "   only-in-new by verdict:"
join -t"$(printf '\t')" -j1 -o 0,2.2 "$TD/onlynew" "$TD/n" \
  | awk -F'\t' '{c[$2]++} END {for (k in c) printf "%8d  %s\n", c[k], k}' | sort -rn
echo "   only-in-new by directory (top 15):"
sed 's/#[0-9]*$//' "$TD/onlynew" | sc_file | awk -F/ '{print (NF>1 ? $1"/"$2 : $1)}' \
  | sort | uniq -c | sort -rn | head -15
echo "   only-in-old by directory (top 15):"
sed 's/#[0-9]*$//' "$TD/onlyold" | sc_file | awk -F/ '{print (NF>1 ? $1"/"$2 : $1)}' \
  | sort | uniq -c | sort -rn | head -15
