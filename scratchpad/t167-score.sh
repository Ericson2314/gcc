#!/bin/sh
# #167 -- score a t167-build.sh run.  REFUSES a log with no `.rc' stamp
# (PRINCIPLES 4: a log being written looks exactly like a log that finished).
#
# It prints the DISTINCT colliding / undefined NAMES rather than line counts,
# because PRINCIPLES 1 is explicit that single defects amplify: 974, 725, 606
# and 94 diagnostics have each come from one cause.  Report causes, not lines.
set -u
D=${1:?build dir}
T=${2:-cc1}
[ -f "$D/make-$T.rc" ] || { echo "REFUSING TO SCORE: $D/make-$T.rc absent -- the build did not finish, or was not run through t167-build.sh"; exit 9; }
rc=$(cat "$D/make-$T.rc")
E="$D/make-$T.err"
[ -s "$E" ] || echo "note: $E is empty"

# Non-vacuity FIRST (PRINCIPLES 7): the scorer must refuse when it cannot show
# it read a real build log.  An all-empty read is indistinguishable from "no
# errors", which is the reading an agent will believe.
ncc=$(grep -c 'mt-[a-z0-9]*/' "$D/make-$T.out" 2>/dev/null || true)
[ "${ncc:-0}" -gt 0 ] || { echo "REFUSING TO SCORE: $D/make-$T.out names no per-base object; this is not a multi-base build log"; exit 9; }
echo "non-vacuity ok: $ncc per-base mentions in the make log"
echo "bases configured: $(cat "$D/MY-LIST" 2>/dev/null | tr ',' '\n' | grep -c .)"
echo "make $T rc=$rc"

# TWO CONCURRENT `ld' PROCESSES INTERLEAVE AT CHARACTER GRANULARITY UNDER -j8,
# AND THE RESULT IS A PLAUSIBLE-LOOKING SYMBOL THAT EXISTS NOWHERE.  Measured,
# not guessed -- make-cc1.err line 2037 of the sixteen-base run reads
#
#   ld.bfdld.bfd: : mt-m68k/m68k.omt-m68k/m68k.o: ... multiple definition of
#   `: multiple definition of `regno_reg_classregno_reg_class''; ...
#
# so a naive extraction yields `regno_reg_classregno_reg_class'.  That is the
# dangerous shape: it is not empty, not obviously corrupt, and reads as a real
# mangled name.  PRINCIPLES 1 already forbids attributing a diagnostic to a
# back end by the nearest preceding line under -j; this is the same hazard
# INSIDE one line, which that rule does not cover.
#
# The defence is to require the captured name to be identifier- or
# C++-signature-shaped and to REPORT what was rejected rather than dropping it
# silently -- a filter that quietly discards malformed input is how a real
# symbol goes missing.  The same run also emits clean, non-interleaved copies
# of every one of these lines, so nothing is lost by being strict.
mt_names () {
  pat=$1
  grep -o "$pat \`[^']*'" "$E" | sed "s/^$pat \`//;s/'\$//" | sort -u > "$D/.mt-raw.$$"
  grep -E '^[A-Za-z_][A-Za-z0-9_]*(\(.*\))?$' "$D/.mt-raw.$$" | sort -u
  bad=$(grep -Ecv '^[A-Za-z_][A-Za-z0-9_]*(\(.*\))?$' "$D/.mt-raw.$$" || true)
  [ "${bad:-0}" = 0 ] || echo "  (${bad} malformed capture(s) rejected as -j interleaving; see $E)"
  rm -f "$D/.mt-raw.$$"
}
echo "--- distinct 'multiple definition' names"
mt_names "multiple definition of"
echo "--- distinct 'undefined reference' names"
mt_names "undefined reference to"
echo "--- distinct 'error:' causes (first 40)"
grep 'error:' "$E" | sed 's/.*error: //' | sort | uniq -c | sort -rn | head -40
echo "--- cc1"
ls -l "$D/gcc/cc1" 2>/dev/null || echo "NO cc1"
