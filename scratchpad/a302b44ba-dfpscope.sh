#!/bin/sh
# THE DFP SCOPE COLUMN, AND THE NEGATIVE CONTROL, FROM A PAIR OF `.sum's.
#
# Task #241's question 3 is "does `dfp.exp' now actually RUN", and question 4 is
# "does a target whose manifest says `decimal_float 0' still get the short one".
# Those are the same measurement asked on two different targets, so they are one
# script, and the target's own manifest line decides which answer is correct.
#
# WHY IT IS COUNTED THIS WAY.  `dfp.exp' does not fail when decimal float is
# off; it produces its `Running ...' banner and stops, because
# `check_effective_target_dfp' compiles a `_Decimal64' TU and gets
# `error: unable to emulate 'DD'`.  So the signal is a RESULT COUNT, not a
# verdict count, and it lands in NEITHER the PASS nor the FAIL column -- which
# is exactly why 858 missing results per target sat under a debt figure of 34
# without moving it.
#
# THE CONTROL IS THE STOCK RUN, not a constant.  749 and 110 are what the stock
# side of one row happened to produce; they are not the definition of "ran".
# Comparing against the control means this still works when the suite changes.
#
# usage: a302b44ba-dfpscope.sh <mt gcc.sum> <stock gcc.sum> <manifest> <triple>
set -u
export LC_ALL=C
MT=${1:?mt gcc.sum}
ST=${2:?stock gcc.sum}
MAN=${3:?multi-target.manifest}
T=${4:?triple}
for f in "$MT" "$ST" "$MAN"; do [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }; done

df=$(awk -v t="$T" '$1=="target"{seen=($2==t)} seen && $1=="decimal_float"{print $2; exit}' "$MAN")
[ -n "$df" ] || { echo "FATAL: $MAN has no decimal_float line for $T"; exit 9; }

n () { grep -c "$1" "$2" 2>/dev/null || true; }
mt_dg=$(n 'gcc\.dg/dfp/'   "$MT"); st_dg=$(n 'gcc\.dg/dfp/'   "$ST")
mt_cc=$(n 'c-c++-common/dfp' "$MT"); st_cc=$(n 'c-c++-common/dfp' "$ST")
mt_t=$((mt_dg+mt_cc)); st_t=$((st_dg+st_cc))

echo "== $T   manifest decimal_float = $df"
printf '  %-22s %10s %10s\n' 'results in'        'MULTI-TARGET' 'STOCK'
printf '  %-22s %10s %10s\n' 'gcc.dg/dfp'        "$mt_dg" "$st_dg"
printf '  %-22s %10s %10s\n' 'c-c++-common/dfp'  "$mt_cc" "$st_cc"
printf '  %-22s %10s %10s\n' 'TOTAL'             "$mt_t"  "$st_t"

# The stock side is the authority on what "ran" means for this target.  If the
# CONTROL produced nothing either, this comparison proves nothing at all and
# must say so rather than printing a matching pair as agreement.
if [ "$st_t" = 0 ]; then
  if [ "$df" = 0 ]; then
    echo "  NOTE: the control produced no dfp results either.  For a"
    echo "  decimal_float=0 target that is the EXPECTED agreement, but it means"
    echo "  this pair cannot distinguish 'correctly off' from 'suite absent'."
    echo "DFPSCOPE[$T]: PASS (negative control: both sides short, as decimal_float 0 requires)"
    exit 0
  fi
  echo "DFPSCOPE[$T]: FATAL -- manifest says decimal_float 1 but the STOCK control"
  echo "  produced 0 dfp results.  The control is broken; no claim can be made."
  exit 9
fi

gap=$((st_t - mt_t))
if [ "$df" = 1 ]; then
  # POSITIVE ARM.  Require the multi-target side to have attempted essentially
  # all of what the control attempted.  The old failure produced mt_t = 1
  # against st_t = 859, so any threshold near parity separates them by three
  # orders of magnitude; 98% is chosen to tolerate genuine per-test differences
  # without tolerating "the suite did not run".
  lo=$(( st_t * 98 / 100 ))
  if [ "$mt_t" -ge "$lo" ]; then
    echo "  gap (stock - mt): $gap"
    echo "DFPSCOPE[$T]: PASS -- dfp.exp RUNS ($mt_t of the control's $st_t attempted)"
    exit 0
  fi
  echo "  gap (stock - mt): $gap   <- results never attempted on the multi-target side"
  echo "DFPSCOPE[$T]: FAIL -- manifest says decimal_float 1, and the multi-target"
  echo "  side attempted only $mt_t of the control's $st_t.  The fix is incomplete."
  exit 1
fi

# NEGATIVE ARM.  decimal_float 0: the multi-target side must be SHORT.  If it
# is not, the fix has become 'turn it on everywhere', which is the same defect
# with the sign flipped and looks like a better board.
hi=$(( st_t / 10 ))
if [ "$mt_t" -le "$hi" ]; then
  echo "DFPSCOPE[$T]: PASS (negative control) -- decimal_float 0 and the"
  echo "  multi-target side attempted $mt_t, the control $st_t.  Short, as required."
  exit 0
fi
echo "DFPSCOPE[$T]: FAIL (negative control) -- manifest says decimal_float 0 but the"
echo "  multi-target side attempted $mt_t dfp results.  Decimal float has been"
echo "  turned on for a target that does not have it: the original defect, inverted."
exit 1
