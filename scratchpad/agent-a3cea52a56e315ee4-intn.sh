#!/bin/sh
# Read the __intN registration OUT OF A RUNNING COMPILER, per back end.
#
# WHY NOT READ THE SOURCE, AND WHY NOT READ insn-modes-<base>.h.  The defect
# this arm exists to witness is not "the header says 2".  Every header already
# said 2 before the fix -- `insn-modes-avr.h' has said `NUM_INT_N_ENTS 2' the
# whole time.  What was broken is that no shared loop ever REACHED entry 1,
# because the loops were bounded by the PRIMARY's 1, so avr's `TI' 128 was
# never registered as a type.  A build that merely compiles proves nothing
# about that, and neither does the generated header.
#
# THE OBSERVABLE.  c-cppbuiltin.cc:1710 walks the entries and defines
# `__SIZEOF_INT<bitsize>__' for each ENABLED one.  So:
#
#   avr      entries { PSI 24, TI 128 }   -> __SIZEOF_INT24__  and __SIZEOF_INT128__
#   msp430   entries { PSI 20, TI 128 }   -> __SIZEOF_INT20__  and __SIZEOF_INT128__
#   x86_64   entries { TI 128 }           -> __SIZEOF_INT128__ only
#
# BEFORE the fix avr's loop stopped after entry 0, so avr got __SIZEOF_INT24__
# and NOT __SIZEOF_INT128__ -- an absence, which is the shape this project
# keeps mistaking for a pass.  So this arm asserts the presence of the SECOND
# entry by name, and asserts x86_64 did NOT gain a spurious one: one-sided
# evidence cannot tell "fixed" from "everyone now gets the same new answer".
#
# `-E -dM' only, so no assembler is needed for any of these targets.
#
# usage: agent-a3cea52a56e315ee4-intn.sh <builddir>
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
V=$(cat "$SRC/gcc/BASE-VER")
OUT="$D/intn"; mkdir -p "$OUT"
[ -x "$D/gcc/cc1" ] || mt_die "no $D/gcc/cc1"

: > "$OUT/empty.c"
fail=0

# triple  must-have (space separated)  must-not-have
check () {
  t=$1; want=$2; unwant=$3
  c="$D/lib/gcc/$V/$t/specs-config"
  [ -s "$c" ] || { echo "$t: NO specs-config at $c -- arm did not run"; fail=1; return; }
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -E -dM -ftarget-config="$c" \
      "$OUT/empty.c" -o "$OUT/$t.dM" ) > "$OUT/$t.out" 2> "$OUT/$t.err"
  r=$?
  if [ "$r" != 0 ] || [ ! -s "$OUT/$t.dM" ]; then
    echo "$t: FAIL rc=$r (no predefines emitted)"
    sed -n 1,6p "$OUT/$t.err"
    fail=1; return
  fi
  # NON-VACUITY: the dump must be a real predefine dump, or every `grep -q'
  # below is answering a question about an empty file.  A missing tool, a
  # truncated write and a genuine absence are the same silence otherwise.
  grep -q '^#define __SIZEOF_LONG__ ' "$OUT/$t.dM" || {
    echo "$t: FATAL: dump has no __SIZEOF_LONG__ -- it is not a predefine dump,"
    echo "  so the __SIZEOF_INT* readings below would prove nothing."
    fail=1; return
  }
  got=$(grep -o '__SIZEOF_INT[0-9]*__' "$OUT/$t.dM" | sort -u | tr '\n' ' ')
  echo "$t: __intN predefines: [$got]"
  for w in $want; do
    grep -q "^#define $w " "$OUT/$t.dM" \
      || { echo "  MISSING $w"; fail=1; }
  done
  for u in $unwant; do
    grep -q "^#define $u " "$OUT/$t.dM" \
      && { echo "  UNEXPECTED $u"; fail=1; }
  done
}

echo "anchor=$n srcdir=$SRC"
check avr-elf     "__SIZEOF_INT24__ __SIZEOF_INT128__" ""
check msp430-elf  "__SIZEOF_INT20__ __SIZEOF_INT128__" ""
# Both-sided: the 45 back ends with ONE entry must not have acquired a second.
check x86_64-pc-linux-gnu "__SIZEOF_INT128__" "__SIZEOF_INT24__ __SIZEOF_INT20__"
check aarch64-unknown-linux-gnu "__SIZEOF_INT128__" "__SIZEOF_INT24__ __SIZEOF_INT20__"

[ "$fail" = 0 ] && echo "int_n registration: OK" || echo "int_n registration: FAILED"
exit "$fail"
