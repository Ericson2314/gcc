#!/bin/sh
# agent-a018835bbcfad2e28-eight.sh -- does TARGET-INDEPENDENT code ask the
# individual eight HAVE_* macros, or only their disjunction?
#
# target-insn.h:97-110 states, as the reason `auto_inc_dec' is ONE field:
#
#   "the question shared code asks is already the disjunction and never the
#    individual eight.  Storing the disjunction is storing the question that
#    is asked; storing the eight would be storing a vocabulary nothing reads."
#
# This counts the reads, so the claim is decided by the tree rather than by
# the sentence.  Only files OUTSIDE config/ count: inside a back end the macro
# is correct already, because that TU is compiled against its own tm.h.
#
# rtl.h's OWN `#ifndef X / #define X 0' fallback lines are excluded -- they
# are the definition under test, not a read of it.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc"
M="HAVE_PRE_INCREMENT HAVE_PRE_DECREMENT HAVE_POST_INCREMENT HAVE_POST_DECREMENT
   HAVE_PRE_MODIFY_DISP HAVE_POST_MODIFY_DISP HAVE_PRE_MODIFY_REG HAVE_POST_MODIFY_REG"

tot=0
for m in $M; do
  n=0; files=
  for f in $(grep -rlw "$m" --include='*.cc' --include='*.h' . 2>/dev/null \
             | grep -v '^./config/' | grep -v '^./testsuite/'); do
    c=$(grep -nw "$m" "$f" \
        | grep -vE '^[0-9]+:#[[:space:]]*(ifndef|define|endif)' \
        | grep -vE '^[0-9]+:[[:space:]]*(\*|/\*|//)' \
        | grep -cv 'defined *(' )
    [ "$c" -gt 0 ] || continue
    n=$((n+c)); files="$files $(basename "$f"):$c"
  done
  tot=$((tot+n))
  printf '%-24s %3d reads outside config/ %s\n' "$m" "$n" "$files"
done
echo
echo "TOTAL individual reads by target-independent code: $tot"
echo
echo "NON-VACUITY: the same counter on a macro that really IS read only as a"
echo "disjunction must be able to score 0.  Control = AUTO_INC_DEC's own"
echo "fallback name, which no target-independent file spells:"
printf '  %-22s %s\n' HAVE_NO_SUCH_MACRO_XYZ \
  "$(grep -rlw HAVE_NO_SUCH_MACRO_XYZ --include='*.cc' --include='*.h' . 2>/dev/null | grep -vc '^./config/')"
echo
echo "-- the decision table in auto-inc-dec.cc that reads them:"
grep -nE 'HAVE_(PRE|POST)_(INCREMENT|DECREMENT|MODIFY_DISP|MODIFY_REG)' auto-inc-dec.cc | sed 's/^/   /'
