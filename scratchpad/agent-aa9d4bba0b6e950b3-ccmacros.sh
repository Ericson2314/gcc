#!/bin/sh
# agent-aa9d4bba0b6e950b3-ccmacros.sh
#
# THE QUESTION: what do the three CC-selection macros expand to in a SHARED
# translation unit, and what does each back end's OWN header chain say?
#
# PRINCIPLES 2a: "ask what the primary's `tm.h' expands a macro to, not
# whether a fallback exists and not whether a converted-macro list names it."
# `defaults.h:1215' has `#ifndef REVERSIBLE_CC_MODE' and `defaults.h:1420' has
# `#ifndef REVERSE_CONDITION' -- both are DEAD if `i386.h' defines the name
# first, which is the `REGMODE_NATURAL_SIZE' trap.  This script does not read
# the `#ifndef'; it reads the expansion.
#
# NON-VACUITY: a control macro that MUST be present is asserted first, so an
# empty read cannot be confused with "the macro is absent".  If `cpp' fails or
# the tm.h is missing we exit 9 by name rather than printing zeroes.
#
# usage: agent-aa9d4bba0b6e950b3-ccmacros.sh <builddir>
set -eu
D=${1:?build dir}
G=$D/gcc
[ -f "$G/tm.h" ] || { echo "FATAL: $G/tm.h absent" >&2; exit 9; }

MACROS='SELECT_CC_MODE REVERSIBLE_CC_MODE REVERSE_CONDITION'
CONTROL='BITS_PER_UNIT'

SRC=$(cat "$D/MY-SRC")

# The generated per-base headers are found by paths RELATIVE to $D/gcc (e.g.
# `s390-inc/insn-attr-common.h'), so the preprocessor has to run with that as
# its working directory.  Running it from anywhere else fails on
# `insn-attr-common.h: No such file' -- which reads as "the build is
# incomplete" and is really "the instrument is in the wrong directory".
probe () {                       # $1 = header to include, $2 = label
  _h=$1; _l=$2
  [ -f "$_h" ] || { echo "$_l: HEADER ABSENT ($_h)"; return; }
  printf '#include "%s"\n' "$_h" > /tmp/ccm-$$.c
  if ! ( cd "$G" && cpp -dM -I "$G" -I "$SRC/gcc" -DIN_GCC /tmp/ccm-$$.c ) \
       > /tmp/ccm-$$.i 2> /tmp/ccm-$$.err; then
    echo "$_l: CPP FAILED -- $(head -1 /tmp/ccm-$$.err)"
    return
  fi
  # non-vacuity: the control must be there, or we are reading nothing.
  grep -q "define $CONTROL " /tmp/ccm-$$.i \
    || { echo "$_l: VACUOUS -- control $CONTROL absent, refusing to score"; return; }
  for m in $MACROS; do
    _v=$(grep "^#define $m[ (]" /tmp/ccm-$$.i | head -1)
    [ -n "$_v" ] || _v="#define $m   <UNDEFINED>"
    echo "$_l  $_v"
  done
  echo
}

echo "=== the SHARED tm.h -- what every shared TU (combine.cc, jump.cc, ...) reads"
probe "$G/tm.h" "shared "

for b in i386 s390 aarch64 riscv rs6000; do
  echo "=== tm-$b.h -- that back end's own answer"
  probe "$G/tm-$b.h" "$b"
done
rm -f /tmp/ccm-$$.c /tmp/ccm-$$.i /tmp/ccm-$$.err
