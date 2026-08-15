#!/bin/sh
# agent-aa9d4bba0b6e950b3-score.sh -- the whole s390x verdict, in one place.
#
# Four questions, and they are four because no one of them can answer another:
#
#   1. BY NAME, before vs after.  `mt-namediff.sh'.  Columns cannot tell a fix
#      from a regression when a fix changes how many results a test produces,
#      and both of these fixes do exactly that: a file that ICEd once now runs
#      its whole check list.  The board records aarch64's FAIL column RISING
#      +38,303 while 87,963 results went UNRESOLVED->PASS.
#   2. THE DEBT against stock, before and after.  A by-name diff of two
#      multi-target runs says what MOVED; only stock says whether what moved
#      was owed.
#   3. THE TWO CAUSES, by name, in each run.  Both are ICE strings, so they can
#      be counted directly in the `.sum' -- but ONLY as raw FAIL counts, never
#      as a share of the debt.  `grep <ICE>' over the DEBT returns 0 by
#      construction (the debt row is the `(test for excess errors)' sibling,
#      which names no diagnostic); `mt-debt-attribute.sh' is the one that asks
#      at file level and labels its answer the upper bound it is.
#   4. THE CAUSE I DID NOT FIX, so its 31,864 is visible in the same table and
#      nobody reads its survival as a failure of the two that were.
#
# usage: agent-aa9d4bba0b6e950b3-score.sh
set -u
export LC_ALL=C
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
O=/tmp/board-agent-aa9d4bba0b6e950b3
STOCK=/tmp/b-stock-agent-a3464debf6893de84-s390x/gcc/testsuite.s390x-ibm-linux-gnu/gcc/gcc.sum

B=$O/before-s390x.sum; A=$O/after-s390x.sum
BL=$O/before-s390x.log; AL=$O/after-s390x.log
for f in "$B" "$A" "$STOCK"; do
  [ -f "$f" ] || { echo "FATAL: no $f" >&2; exit 9; }
  grep -q '=== gcc Summary' "$f" || { echo "FATAL: $f truncated" >&2; exit 9; }
done
# The `.rc' stamp, not the `=== gcc Summary' marker: the marker passes on a
# sixth of a run.
for r in "$O/before-s390x.rc" "$O/after-s390x.rc"; do
  [ -f "$r" ] || { echo "FATAL: no $r -- the run did not finish" >&2; exit 9; }
  echo "stamp $(basename "$r") rc=$(cat "$r")"
done

echo
echo "==================== 1. COLUMNS (printed, not relied on)"
for t in before after; do
  printf '%-8s ' "$t"
  grep -E '^# of ' "$O/$t-s390x.sum" | tr '\n' ' '; echo
done
printf '%-8s ' stock; grep -E '^# of ' "$STOCK" | tr '\n' ' '; echo

echo
echo "==================== 2. BY NAME, before -> after"
sh "$W/scratchpad/mt-namediff.sh" "$B" "$A" s390x-before-vs-after

echo
echo "==================== 3. THE DEBT AGAINST STOCK"
for t in before after; do
  echo "-- $t"
  sh "$W/scratchpad/mt-debt-attribute.sh" "$O/$t-s390x.sum" "$STOCK" \
     's390_match_ccmode_set' 2>&1 | sed 's/^/   /'
done

echo
echo "==================== 4. RAW FAIL COUNTS PER CAUSE (not debt shares)"
printf '%-46s %10s %10s\n' CAUSE BEFORE AFTER
for pat in 's390_match_ccmode_set' 'internal compiler error: Segmentation fault' \
           'hashtab_chk_error'; do
  printf '%-46s %10s %10s\n' "$pat" \
    "$(grep -c "^FAIL:.*$pat" "$B" || true)" \
    "$(grep -c "^FAIL:.*$pat" "$A" || true)"
done
# The cause NOT fixed, counted in the LOG because it is an assembler message
# and never reaches a test name.
if [ -f "$BL" ] && [ -f "$AL" ]; then
  printf '%-46s %10s %10s\n' 'as: operand out of range (NOT FIXED)' \
    "$(grep -c 'operand out of range' "$BL" || true)" \
    "$(grep -c 'operand out of range' "$AL" || true)"
fi
