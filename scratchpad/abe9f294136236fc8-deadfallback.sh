#!/bin/sh
# SWEEP THE FAMILY: which of `defaults.h''s `#ifndef' fallbacks are DEAD
# because the primary's header chain defines the name first?
#
# WHY.  `STACK_SAVEAREA_MODE' was the THIRD instance of this shape --
# `REGMODE_NATURAL_SIZE' (509 ICEs) and `EPILOGUE_USES' (9,050 FAILs in one
# directory) are the first two, and PRINCIPLES states the rule they share:
#
#     An `#ifndef' in a shared TU is never taken if the primary defines the
#     name, so "it has a fallback" is not evidence the fallback runs.
#
# Each of the three was found by walking into it during an unrelated debug
# session.  PRINCIPLES' own instruction for that situation is to enumerate the
# whole family rather than meet it one wall at a time.  This is that
# enumeration.
#
# WHAT IT ASKS, AND WHAT IT CANNOT ANSWER.  For each name `defaults.h' guards
# with `#ifndef':
#
#   DEAD-LEAK    the primary's chain defines it AND `multi-target-macros.h'
#                does not redirect it  -> shared code reads i386's answer and
#                `defaults.h''s fallback never runs.  A CANDIDATE, not a bug:
#                whether it matters depends on whether the value differs
#                between back ends and on whether shared code reads it at all.
#   REDIRECTED   the primary defines it but the conversion layer displaces it.
#   LIVE         the primary's chain does NOT define it, so the fallback is
#                genuinely what shared code gets.
#
# It is deliberately OVER-BROAD in the DEAD-LEAK direction, per PRINCIPLES:
# "when an instrument can only take away, make it too eager; when it can grant,
# make it exact."  This one can only ever ADD a name to a queue, never bless
# one as fine, so a false DEAD-LEAK costs a reading and a false LIVE costs a
# bug.  Erring towards DEAD-LEAK is the cheap direction.
#
# THE PRIMARY'S SET IS READ WITH `cpp -dM' FROM THE BUILD DIR, NOT GREPPED.
# PRINCIPLES, twice: "ask what the compiler actually reads, not what the
# directory layout suggests" -- `config/elfos.h' and `config/gnu-user.h' sit
# one level above `config/i386/' and are in the chain, and a `config/'-scoped
# grep scored 66 of 87 pairs wrong for exactly that reason.
#
# usage: abe9f294136236fc8-deadfallback.sh <builddir> <srcdir>
set -u
B=${1:?build dir}; S=${2:?srcdir}
[ -f "$B/gcc/tm.h" ] || { echo "FATAL: no $B/gcc/tm.h -- build the tree first"; exit 9; }
[ -f "$S/gcc/defaults.h" ] || { echo "FATAL: no $S/gcc/defaults.h"; exit 9; }

# 1. every name `defaults.h' guards with `#ifndef' AND then `#define's.
awk '
  /^#[ \t]*ifndef[ \t]+[A-Za-z_]/ { g = $2; next }
  /^#[ \t]*define[ \t]+[A-Za-z_]/ {
     n = $2; sub(/\(.*/, "", n);
     if (g != "" && n == g) print n;
     next }
  /^#[ \t]*endif/ { g = "" }
' "$S/gcc/defaults.h" | sort -u | grep -vx GCC_DEFAULTS_H > /tmp/df-guarded-$$
# `GCC_DEFAULTS_H' IS THE FILE'S OWN INCLUDE GUARD, not a target macro, and it
# matches the pattern perfectly (`#ifndef X' / `#define X').  It is also the
# name step 2 pre-defines, so it scored DEAD-LEAK -- the instrument reporting
# its own `-D' back to itself.  Harmless, one row, and excluded because a
# queue with a known-bogus entry in it invites the reader to discount the rest.
NG=$(grep -c . /tmp/df-guarded-$$)
echo "== defaults.h guards $NG names with a matching #ifndef/#define pair"
[ "$NG" -gt 20 ] || { echo "FATAL: only $NG -- the awk is not matching; refusing to score"; exit 9; }

# 2. what the PRIMARY's chain actually defines, from the compiler.
#
# `-DGCC_DEFAULTS_H' IS LOAD-BEARING AND THE FIRST DRAFT DID NOT HAVE IT.
# `mkconfig.sh' appends `#include "defaults.h"' to the END of `tm.h', so a
# plain `cpp -dM -include tm.h' reports the macro set AFTER defaults.h has
# run -- in which every guarded name is defined BY CONSTRUCTION, because
# defaults.h just defined the ones nobody else had.  The first run scored
# `LIVE 0' of 215, i.e. "every fallback is pre-empted", which is not a
# measurement of anything: it is the instrument reading its own subject's
# output.  Pre-defining defaults.h's own include guard makes its body a no-op
# and leaves exactly the back-end chain's definitions, which is the question.
#
# The tell was the number: `LIVE 0' is too clean.  A result with no exceptions
# at all, on a population of 215 assembled by different people over thirty
# years, is likelier to be an instrument artefact than a fact -- and it was.
( cd "$B/gcc" && echo '' | cpp -dM -I. -I"$S/gcc" -I"$S/gcc/../include" \
    -DIN_GCC -DGCC_DEFAULTS_H -include tm.h - ) 2> /tmp/df-cpp-err-$$ \
  | sed -n 's/^#define \([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' | sort -u > /tmp/df-primary-$$
NP=$(grep -c . /tmp/df-primary-$$)
echo "== the primary's tm.h chain defines $NP names (defaults.h body suppressed)"
# THE CONTROL FOR THAT SUPPRESSION.  If `GCC_DEFAULTS_H' stopped being
# defaults.h's guard name, the `-D' would silently do nothing and we would be
# back to reading defaults.h's own output with no diagnostic.  So require a
# name defaults.h defines and NO back-end header does to be ABSENT here.
grep -qx 'DWARF_CIE_DATA_ALIGNMENT' /tmp/df-primary-$$ && {
  echo "FATAL: DWARF_CIE_DATA_ALIGNMENT is present, so defaults.h still ran;"
  echo "       -DGCC_DEFAULTS_H is no longer suppressing it."; exit 9; }
echo "== control: defaults.h's own DWARF_CIE_DATA_ALIGNMENT is absent, as it must be"
# NON-VACUITY, AND IT IS THE WHOLE POINT.  A `cpp' that failed writes an empty
# set, every name scores LIVE, and the report reads "nothing is leaking" --
# the null-result-as-a-pass shape.  Refuse instead.
[ "$NP" -gt 500 ] || {
  echo "FATAL: only $NP macros from cpp -- it did not run; NOT scoring."
  echo "-- cpp stderr:"; head -5 /tmp/df-cpp-err-$$; exit 9; }
# And a POSITIVE control: a name the chain must define, or the set is not the
# chain's.
grep -qx 'TARGET_64BIT' /tmp/df-primary-$$ || {
  echo "FATAL: TARGET_64BIT absent -- that is not i386's chain"; exit 9; }

# 3. what the conversion layer displaces.
sed -n 's/^#[ \t]*undef[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' \
  "$S/gcc/multi-target-macros.h" | sort -u > /tmp/df-redirected-$$
echo "== multi-target-macros.h #undefs $(grep -c . /tmp/df-redirected-$$) names"

echo
printf '%-40s %s\n' NAME VERDICT
ndead=0; nred=0; nlive=0
while read -r n; do
  [ -n "$n" ] || continue
  if ! grep -qx "$n" /tmp/df-primary-$$; then
    printf '%-40s LIVE\n' "$n"; nlive=$((nlive+1))
  elif grep -qx "$n" /tmp/df-redirected-$$; then
    printf '%-40s REDIRECTED\n' "$n"; nred=$((nred+1))
  else
    printf '%-40s DEAD-LEAK\n' "$n"; ndead=$((ndead+1))
  fi
done < /tmp/df-guarded-$$

echo
echo "== DEAD-LEAK $ndead   REDIRECTED $nred   LIVE $nlive   (of $NG)"
echo "== DEAD-LEAK is a QUEUE, not a bug list: each name still needs asking"
echo "   whether its value differs between back ends and whether shared code"
echo "   reads it.  STACK_SAVEAREA_MODE was on this list and was worth 69 rows."
rm -f /tmp/df-guarded-$$ /tmp/df-primary-$$ /tmp/df-redirected-$$ /tmp/df-cpp-err-$$
