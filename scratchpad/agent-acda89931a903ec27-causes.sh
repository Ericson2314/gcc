#!/bin/sh
# Rank failure causes BY HOW MANY BACK ENDS SHARE THEM, and separately by how
# many results they account for.  BOTH orderings are printed because they
# disagree, and the disagreement is the finding.
#
# WHY BREADTH IS THE PRIMARY ORDERING.  A cause on six back ends is one defect
# in shared code; a cause with 9,000 results on one back end is that back
# end's problem.  Ranking by volume alone puts the second first and has
# repeatedly hidden the first -- `extract_insn' was on six of ten back ends
# and was recorded as "someone fixed it" when it was merely invisible behind
# a louder single-target number.
#
# THE COUNT IS OF BACK ENDS, NOT OCCURRENCES.  An earlier instrument on this
# branch counted occurrences of a demangled name and reported 51 collisions
# that were one back end's C++ overload set.  Here each (cause, backend) pair
# is counted once before any ranking happens.
set -u
OUT=${OUT:?dir holding gcc-<be>.log and rows.txt}
ROWS="$OUT/rows.txt"
[ -f "$ROWS" ] || { echo "FATAL: no $ROWS"; exit 9; }

PAIRS="$OUT/cause-pairs.txt"
: > "$PAIRS"

nlog=0
for f in "$OUT"/gcc-*.log; do
  [ -f "$f" ] || continue
  be=$(basename "$f" .log); be=${be#gcc-}
  nlog=$((nlog+1))
  # ICE signatures: the function or file:line the compiler died in.
  sed -n 's/.*internal compiler error: \(.*\)/\1/p' "$f" \
    | sed 's/[0-9][0-9]*/N/g; s/  */ /g' | sort -u \
    | while IFS= read -r c; do printf 'ICE\t%s\t%s\n' "$be" "$c"; done >> "$PAIRS"
  # hard errors that are not ICEs
  sed -n 's/.*: error: \(.*\)/\1/p' "$f" \
    | sed "s/'[^']*'/'X'/g; s/[0-9][0-9]*/N/g; s/  */ /g" | sort -u \
    | while IFS= read -r c; do printf 'ERROR\t%s\t%s\n' "$be" "$c"; done >> "$PAIRS"
  # assembler refusals -- a DIFFERENT search from a compiler defect
  sed -n 's/.*Assembler messages.*//p;s/.*Error: \(.*\)/\1/p' "$f" \
    | sed "s/'[^']*'/'X'/g; s/[0-9][0-9]*/N/g; s/  */ /g" | sort -u \
    | while IFS= read -r c; do printf 'ASM\t%s\t%s\n' "$be" "$c"; done >> "$PAIRS"
done

# DIED-FIRST-INPUT rows have no .sum and no .log, and are invisible to
# everything above.  They are the null-result shape this board exists to make
# visible, so they are folded in from rows.txt by their recorded message.
awk '$3=="DIED-FIRST-INPUT" {be=$1; $1=$2=$3=$4=$5=$6=$7=""; sub(/^ +/,"");
     gsub(/[0-9]+/,"N"); printf "DIED\t%s\t%s\n", be, $0}' "$ROWS" >> "$PAIRS"

[ -s "$PAIRS" ] || { echo "NOTE: no causes extracted from $nlog logs"; exit 0; }
sort -u "$PAIRS" -o "$PAIRS"

echo "=== logs read: $nlog   distinct (kind,backend,cause) pairs: $(wc -l < "$PAIRS")"
echo
echo "=== ORDERING 1: by NUMBER OF BACK ENDS sharing the cause (breadth) ==="
awk -F'\t' '{k=$1 FS $3; n[k]++; if (b[k] !~ $2) b[k]=b[k] " " $2}
     END{for (i in n) printf "%3d  %s\n     backends:%s\n", n[i], i, b[i]}' "$PAIRS" \
  | paste - - | sort -rn | head -25 | tr '\t' '\n'

echo
echo "=== ORDERING 2: by TOTAL RESULTS the cause accounts for (volume) ==="
for f in "$OUT"/gcc-*.log; do
  [ -f "$f" ] || continue
  be=$(basename "$f" .log); be=${be#gcc-}
  sed -n 's/.*internal compiler error: \(.*\)/\1/p' "$f" | sed 's/[0-9][0-9]*/N/g'
done | sort | uniq -c | sort -rn | head -25

echo
echo "NOTE: ordering 1 counts each (cause, back end) ONCE; ordering 2 counts"
echo "every occurrence.  Where they disagree, ordering 1 is the shared-code"
echo "defect and ordering 2 is usually one back end's own volume."
