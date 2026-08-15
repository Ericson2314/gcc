#!/bin/sh
# mt-debt-attribute.sh -- how much of a target's DEBT belongs to tests that hit
# a given diagnostic.  UPPER BOUND, and it says so.
#
# WHY THIS IS NOT `grep <ICE> | wc -l' OVER THE DEBT, WHICH IS WHAT I TRIED
# FIRST AND WHICH RETURNS ZERO ON A TARGET WHERE THE CAUSE IS DOMINANT.
#
# A DejaGnu test NAME includes the diagnostic:
#
#     FAIL: gcc.dg/foo.c  -O2  (internal compiler error: in ..., at regs.h:312)
#     FAIL: gcc.dg/foo.c  -O2  (test for excess errors)
#
# Stock produces neither line -- it PASSES -- so when the two runs are joined
# by (name, occurrence), the ICE-annotated row has NO counterpart on the stock
# side and lands in ONLY-IN-MULTI-TARGET, not in the debt.  The row that DOES
# join, and therefore the row that IS the debt, is the `(test for excess
# errors)' sibling, whose text contains no diagnostic at all.
#
# So `grep in_hard_reg_set_p' over the debt returns **0** on x86_64, where that
# ICE is the dominant cause of 1,756 failures.  A zero, from a correct-looking
# pipeline, in the direction that says the cause does not matter.  I asserted
# "one cause is 59% of the debt" off exactly that arithmetic before checking
# it, and it was wrong.
#
# The sound question is at the FILE level: how many debt results belong to test
# FILES that hit this diagnostic anywhere in the run.  That is an UPPER BOUND,
# because a file that ICEs at -O2 may owe some of its debt to something else
# entirely, and the script prints it as one.  There is no lower bound available
# from a .sum -- getting one means re-running those files with the cause fixed.
#
# usage: mt-debt-attribute.sh <mt-sum> <stock-sum> <diagnostic-pattern>
set -u
export LC_ALL=C
MT=${1:?multi-target gcc.sum}
ST=${2:?stock gcc.sum}
PAT=${3:?diagnostic pattern}

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
awk -F'\t' '$2=="PASS" && $3!="PASS" {print $1}' "$TD/j" > "$TD/debt"
tot=$(wc -l < "$TD/debt")
[ "$tot" -gt 0 ] || { echo "FATAL: total debt 0 -- refusing"; exit 9; }

# the FILES that hit the diagnostic (first whitespace token of the name)
grep -E "$PAT" "$MT" | sed -e 's/^[A-Z]*: //' -e 's/[ 	].*//' | sort -u > "$TD/files"
nf=$(wc -l < "$TD/files")
# NON-VACUITY: a pattern matching no file is a broken pattern, not a clean
# target, and it produces the same `0' as a cause that is genuinely absent.
[ "$nf" -gt 0 ] || {
  echo "-- total debt $tot;  files matching /$PAT/: 0"
  echo "   (a real zero ONLY if you have independently seen this diagnostic"
  echo "    absent from the log -- otherwise the pattern is wrong)"
  exit 0
}
sed -e 's/#[0-9]*$//' -e 's/[ 	].*//' "$TD/debt" | sort > "$TD/debtfiles"
hit=$(join "$TD/debtfiles" "$TD/files" | wc -l)
echo "-- total debt: $tot"
echo "-- files hitting /$PAT/: $nf"
echo "-- debt results in those files: $hit   ($((hit * 100 / tot))% of the debt)"
echo "   UPPER BOUND: a file that hits this diagnostic at one option level may"
echo "   owe some of its debt to an unrelated cause.  No lower bound is"
echo "   derivable from a .sum -- that needs a re-run with the cause fixed."
