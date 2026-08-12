#!/usr/bin/env bash
#
# NON-VACUITY FOR THE PER-BASE OPTION TABLES -- TWO SEPARATE ARMS.
#
# "Presence of a mechanism is not evidence anything invokes it."  That has been
# hit five times on this branch, the last time inside a selector: the per-base
# `targetm_asm_ops' tables were built and correct, TAB scored them PASS, and
# nothing ever pointed the selector at them -- `target_asm_ops_for ()' had no
# caller in the tree.  So this file puts an arm on the DATA and a separate arm
# on WHETHER THE SELECTION HAPPENS, and both must be green.
#
#   ARM A  (data)       xgcc contains cl_options_i386 AND cl_options_aarch64,
#                       at DISTINCT addresses, and likewise cl_enums_*.  Two
#                       symbols at one address is what a "union" that quietly
#                       aliased both bases onto the primary would look like.
#   ARM B  (selection)  gcc.o -- the driver's own object, not the selector's --
#                       carries an UNDEFINED reference to
#                       multi_target_options_select.  A call deleted, ifdef-ed
#                       out or folded away leaves no relocation and this goes
#                       red.  A grep of the source is the class of evidence
#                       that already failed here, so it is not used.
#   ARM C  (control)    the SHARED symbol `cl_options' must exist as an OBJECT
#                       (the pointer) and NOT as a large array.  This is what
#                       distinguishes "the tables are now per base" from "a
#                       second copy was added next to the primary's".
#
# CONTROLS, both required, so the checker is shown able to report either answer:
#   POSITIVE  a function gcc.cc demonstrably calls (targetm_common_select) must
#             be found undefined in gcc.o.  Without it a broken nm invocation
#             reports everything missing, red for no reason.
#   NEGATIVE  a real function gcc.cc does NOT call must NOT be found.
#
# Never pipes into `grep -q' under pipefail: grep -q exits at the first hit, nm
# dies of SIGPIPE, and the SUCCESSFUL case reports failure.  Everything goes to
# a file first.
#
# USAGE:  scratchpad/optsel-arm.sh [builddir]     default /tmp/b-a79
set -u -o pipefail
BUILD=${1:-/tmp/b-a79}
OUT=${OUT:-/tmp/optsel-arm}
rm -rf "$OUT"; mkdir -p "$OUT"

command -v nm > /dev/null || { echo "FATAL: no nm on PATH"; exit 9; }

XGCC="$BUILD/gcc/xgcc"
GCCO="$BUILD/gcc/gcc.o"
for f in "$XGCC" "$GCCO"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done

rc=0
say () { echo "$1 $2"; [ "$1" = FAIL ] && rc=1; return 0; }

nm "$XGCC" > "$OUT/nm-xgcc.txt" 2> "$OUT/nm-xgcc.err"
nm "$GCCO" > "$OUT/nm-gcco.txt" 2> "$OUT/nm-gcco.err"
# A tool that produced nothing must not be read as "the symbol is absent".
for f in nm-xgcc nm-gcco; do
  n=$(wc -l < "$OUT/$f.txt")
  [ "$n" -gt 100 ] || { echo "FATAL: nm produced $n lines for $f; see $OUT/$f.err"; exit 9; }
done

echo "== ARM A: per-base tables present, at distinct addresses =="
addr_of () { awk -v s="$1" '$3 == s { print $1; exit }' "$OUT/nm-xgcc.txt"; }
for s in cl_options_i386 cl_options_aarch64 cl_enums_i386 cl_enums_aarch64; do
  a=$(addr_of "$s")
  if [ -n "$a" ]; then echo "   $s @ $a"; else say FAIL "ARM A: $s absent from xgcc"; fi
done
oi=$(addr_of cl_options_i386); oa=$(addr_of cl_options_aarch64)
ei=$(addr_of cl_enums_i386);   ea=$(addr_of cl_enums_aarch64)
if [ -n "$oi" ] && [ -n "$oa" ]; then
  [ "$oi" != "$oa" ] && say PASS "ARM A: cl_options_* at distinct addresses" \
                     || say FAIL "ARM A: both cl_options_* at $oi -- aliased, not per base"
fi
if [ -n "$ei" ] && [ -n "$ea" ]; then
  [ "$ei" != "$ea" ] && say PASS "ARM A: cl_enums_* at distinct addresses" \
                     || say FAIL "ARM A: both cl_enums_* at $ei -- aliased, not per base"
fi

echo "== ARM B: the driver actually calls the selector =="
# The names are C++-MANGLED in the object -- `U _Z27multi_target_options_selectPKc'
# -- so an exact match on $2 finds nothing and reports every callee missing.
# The positive control caught precisely that on the first run; it is the reason
# the control is here.  Match the identifier inside the mangled name, anchored
# on the length prefix so a substring of a longer name cannot pass.
undef_in_gcco () {
  awk -v s="$1" '$1 == "U" && index($2, length(s) s) { f = 1 }
                 END { exit !f }' "$OUT/nm-gcco.txt"
}
undef_in_gcco multi_target_options_select \
  && say PASS "ARM B: gcc.o has an undefined ref to multi_target_options_select" \
  || say FAIL "ARM B: gcc.o does NOT reference multi_target_options_select -- the tables are selectable and nothing selects them"
undef_in_gcco targetm_common_select \
  && say PASS "ARM B control+: targetm_common_select found (nm/awk is working)" \
  || say FAIL "ARM B control+: targetm_common_select NOT found -- the checker is broken, ignore its other answers"
undef_in_gcco multi_target_no_such_function_xyzzy \
  && say FAIL "ARM B control-: a name gcc.cc cannot call was reported present -- the checker answers yes to everything" \
  || say PASS "ARM B control-: a non-callee is correctly not found"

echo "== ARM C: the shared name is a pointer, not a second array =="
# The pointer is 8 bytes; the primary's table is hundreds of KB.  `nm -S' gives
# the size, so this distinguishes "cl_options became a pointer" from "cl_options
# is still the primary's array and per-base copies were added beside it" --
# which would pass ARM A while leaving the bug exactly in place.
nm -S "$XGCC" > "$OUT/nmS.txt" 2> "$OUT/nmS.err"
sz=$(awk '$4 == "cl_options" { print $2; exit }' "$OUT/nmS.txt")
if [ -z "$sz" ]; then
  say FAIL "ARM C: no sized symbol cl_options in xgcc at all"
else
  d=$((16#$sz))
  echo "   cl_options size = 0x$sz ($d bytes)"
  [ "$d" -le 16 ] && say PASS "ARM C: cl_options is a pointer-sized object" \
                  || say FAIL "ARM C: cl_options is $d bytes -- still an array, the primary's table is still the shared one"
fi
szi=$(awk '$4 == "cl_options_i386" { print $2; exit }' "$OUT/nmS.txt")
if [ -n "$szi" ]; then
  di=$((16#$szi))
  echo "   cl_options_i386 size = 0x$szi ($di bytes)"
  [ "$di" -gt 100000 ] && say PASS "ARM C control: the per-base table is a real table" \
                       || say FAIL "ARM C control: cl_options_i386 is only $di bytes -- that is not an option table"
fi

echo "OVERALL rc=$rc"
exit $rc
