#!/bin/sh
# #158 -- BOTH-SIDED artefact arms for the genmodes mode_ibit/mode_fbit fix.
#
# Two defects, one measurement each, and an arm that the fix did NOT become a
# blanket "drop const so it compiles" -- which is the shape section 2a warns
# about and would have made all eight tables writable by the middle end.
#
# usage: t158-ibit-arms.sh <before-builddir> <after-builddir>
set -e
B=${1:?before build dir}/gcc
A=${2:?after build dir}/gcc
fail=0

# NON-VACUITY FIRST.  Every arm below is a grep over a generated file; if the
# file is absent each grep reads nothing and each arm reads as a pass.
for f in "$B/mt-avr/insn-modes-avr.cc" "$A/mt-avr/insn-modes-avr.cc" \
         "$A/mt-i386/insn-modes-i386.cc" "$A/insn-modes.h" "$B/insn-modes.h"; do
  [ -s "$f" ] || { echo "FATAL: $f missing or empty; arms would be vacuous"; exit 9; }
done
echo "non-vacuity: all five generated inputs present and non-empty"

# ---------------------------------------------------------------- defect 1
echo
echo "DEFECT 1 -- ORDER: the table must be defined before the code that writes it"
for tag in ibit fbit; do
  for side in B A; do
    eval d=\$$side
    def=$(grep -n "mode_${tag}_tab\[NUM_MACHINE_MODES\] =" "$d/mt-avr/insn-modes-avr.cc" | head -1 | cut -d: -f1)
    use=$(grep -n "^init_adjust_machine_modes" "$d/mt-avr/insn-modes-avr.cc" | head -1 | cut -d: -f1)
    [ -n "$def" ] && [ -n "$use" ] || { echo "  FATAL: could not locate mode_${tag}_tab / init_adjust_machine_modes in $side"; exit 9; }
    if [ "$def" -lt "$use" ]; then r="definition $def BEFORE writer $use  OK"; else r="definition $def AFTER writer $use  FORWARD REFERENCE"; fi
    echo "  avr $side mode_${tag}_tab: $r"
  done
done

# ---------------------------------------------------------------- defect 2
echo
echo "DEFECT 2 -- CONSTNESS: avr writes mode_ibit/mode_fbit through the SHARED"
echo "            name, so the shared qualifier cannot be const for anybody."
echo "  after, shared insn-modes.h:"
grep -E '^#define CONST_MODE_(IBIT|FBIT)' "$A/insn-modes.h" | sed 's/^/    /'
echo "  before, shared insn-modes.h:"
grep -E '^#define CONST_MODE_(IBIT|FBIT)' "$B/insn-modes.h" | sed 's/^/    /'
grep -qE '^#define CONST_MODE_IBIT$' "$A/insn-modes.h" || { echo "  FAIL: CONST_MODE_IBIT is still qualified"; fail=1; }
grep -qE '^#define CONST_MODE_FBIT$' "$A/insn-modes.h" || { echo "  FAIL: CONST_MODE_FBIT is still qualified"; fail=1; }

echo
echo "  NOT A BLANKET DROP -- the other six must STILL be const.  This is the"
echo "  arm that separates the measured fix from 'make the error go away'."
six=0
for m in NUNITS PRECISION SIZE UNIT_SIZE BASE_ALIGN MASK; do
  if grep -qE "^#define CONST_MODE_$m const\$" "$A/insn-modes.h"; then
    six=$((six + 1))
  else
    echo "    FAIL: CONST_MODE_$m is no longer const"; fail=1
  fi
done
echo "    $six of 6 still const"
[ "$six" = 6 ] || fail=1

# ------------------------------------------------------- both-sided on bases
echo
echo "BOTH-SIDED: the type is now uniform across bases (that is the point), and"
echo "            the DATA is per base and unchanged."
for b in avr i386; do
  d="$A/mt-$b/insn-modes-$b.cc"
  [ -s "$d" ] || { echo "  FATAL: $d missing"; exit 9; }
  t=$(grep -o "^[a-z ]*unsigned char mode_ibit_tab" "$d" | head -1)
  p=$(grep -o "^[a-z ]*unsigned char \*mode_ibit" "$d" | head -1)
  echo "  $b: array '$t' ; pointer '$p'"
  case "$t" in *const*) echo "    FAIL: $b's array is still const"; fail=1 ;; esac
  case "$p" in *const*) echo "    FAIL: $b's pointer is still const"; fail=1 ;; esac
done

echo
echo "  VALUES unchanged -- a qualifier and an order moved, not a number."
for b in avr i386; do
  nb=$(sed -n '/mode_ibit_tab\[NUM_MACHINE_MODES\] =/,/^};/p' "$B/mt-$b/insn-modes-$b.cc" | grep -c . || true)
  na=$(sed -n '/mode_ibit_tab\[NUM_MACHINE_MODES\] =/,/^};/p' "$A/mt-$b/insn-modes-$b.cc" | grep -c . || true)
  sb=$(sed -n '/mode_ibit_tab\[NUM_MACHINE_MODES\] =/,/^};/p' "$B/mt-$b/insn-modes-$b.cc" | grep -o '[0-9]*,' | md5sum | cut -c1-12)
  sa=$(sed -n '/mode_ibit_tab\[NUM_MACHINE_MODES\] =/,/^};/p' "$A/mt-$b/insn-modes-$b.cc" | grep -o '[0-9]*,' | md5sum | cut -c1-12)
  echo "    $b mode_ibit: $nb lines / $sb  ->  $na lines / $sa"
  [ "$sb" = "$sa" ] || { echo "      FAIL: $b's mode_ibit VALUES changed"; fail=1; }
done
# AND THE OBVIOUS DISCRIMINATOR IS TAUTOLOGICAL HERE -- recorded rather than
# quietly swapped out, because finding that out is the result.
#
# The first draft of this arm required avr's and i386's mode_ibit BODIES to
# differ, on the reasoning that a per-base table must be per base.  It FAILED:
# the two are byte-identical (md5 8aff842958a6, values 0/8/16/32/64).  That is
# CORRECT and not a defect.  `ibit' is a property of a fixed-point MODE, the
# mode VOCABULARY is unioned across all 48 back ends, and the static table is
# the vocabulary's own data -- so it is identical everywhere BY CONSTRUCTION,
# and any arm comparing it is green for that reason and no other (PRINCIPLES
# section 6, on why a union macro needs a probe shape of its own).
#
# What is genuinely per base is the ADJUSTMENT: avr has ADJUST_IBIT/ADJUST_FBIT
# and writes the table at startup; no other back end does.  That is also
# exactly the code that failed to compile, so it is the right discriminator.
wa=$(grep -c 'mode_ibit\[E_' "$A/mt-avr/insn-modes-avr.cc" || true)
wi=$(grep -c 'mode_ibit\[E_' "$A/mt-i386/insn-modes-i386.cc" || true)
echo "    per-base ADJUSTMENT (the real discriminator, not the static table):"
echo "      avr writes mode_ibit at startup $wa time(s); i386 $wi"
[ "$wa" -gt 0 ] || { echo "      FAIL: avr adjusts nothing; the wall could not have existed"; fail=1; }
[ "$wi" = 0 ] || { echo "      FAIL: i386 unexpectedly adjusts mode_ibit"; fail=1; }

echo
[ "$fail" = 0 ] && echo "ALL ARMS PASS" || { echo "SOME ARM FAILED"; exit 1; }
