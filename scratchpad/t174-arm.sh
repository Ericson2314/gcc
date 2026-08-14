#!/bin/sh
# #174 -- THE arm ARM.  Run cc1 for arm and read what it says and what it
# emits.
#
# Two things are checked and they are different questions:
#
#   1. the `target_expmed' LAYOUT WITNESS (reginfo.cc:238).  Before this task
#      it fired for arm, because `NUM_MODE_INT' is derived from
#      `MIN_MODE_INT' and arm's insn-modes.h disagreed with the shared one.
#   2. a SEMANTIC property of the output.  "It stopped erroring" and "it
#      assembles" are both satisfied by silently wrong code -- riscv64 passed
#      "assembles, right ELF machine" while emitting 32-bit code (PRINCIPLES
#      sec 4).  arm is a 32-bit target, so the discriminator is the reverse:
#      the output must NOT be 64-bit, and must name arm registers.
#
# usage: t174-arm.sh <builddir> <tag>
set -u
D=${1:?build dir}
TAG=${2:?tag}
V=17.0.0
T=arm-unknown-eabi
OUT=$D/$TAG-arm
mkdir -p "$OUT"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }

c=$D/lib/gcc/$V/$T/specs-config
[ -s "$c" ] || { echo "NOTE: no specs-config for $T at $c (witness arm only)"; c=; }

cat > "$OUT/w.c" <<'EOF'
long mt_shift (long a, int b) { return (a << b) + (a >> b); }
int  mt_add   (int a)         { return a + 1; }
EOF

if [ -n "$c" ]; then
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" \
      "$OUT/w.c" -o "$OUT/w.s" ) > "$OUT/w.out" 2> "$OUT/w.err"
else
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 \
      "$OUT/w.c" -o "$OUT/w.s" ) > "$OUT/w.out" 2> "$OUT/w.err"
fi
r=$?
echo "cc1 rc=$r  in=$OUT/w.c"

echo "-- layout witness (target_expmed / any MT_CHECK_LAYOUT)"
if grep -q 'computes .sizeof' "$OUT/w.err"; then
  grep -h 'computes .sizeof' "$OUT/w.err" | sed 's/^/  FIRES: /'
else
  echo "  silent"
fi
sed -n 1,6p "$OUT/w.err" | sed 's/^/  err: /'

echo "-- semantic arm"
if [ -s "$OUT/w.s" ]; then
  echo "  bytes $(wc -c < "$OUT/w.s")  md5 $(md5sum < "$OUT/w.s" | cut -c1-12)"
  echo "  arm register names (r0-r9,sp,lr,pc): $(grep -cE '\b(r[0-9]|sp|lr|pc)\b' "$OUT/w.s")"
  echo "  x86 register names (%rax etc):       $(grep -cE '%(r|e)[a-z0-9]+' "$OUT/w.s")"
  echo "  aarch64 64-bit regs (x0-x9):         $(grep -cE '\bx[0-9]\b' "$OUT/w.s")"
  echo "  .cpu/.arch/.fpu directives:"
  grep -E '^\s*\.(cpu|arch|fpu|syntax|thumb|arm)\b' "$OUT/w.s" | sed 's/^/    /'
else
  echo "  NO OUTPUT"
fi
