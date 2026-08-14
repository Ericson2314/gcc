#!/bin/sh
# #149/#154 -- can each configured back end be SELECTED, and what does it emit?
#
# PRINCIPLES section 4: "WHERE DOES IT ICE" IS NOT THE MEASUREMENT, "IS THE
# OUTPUT RIGHT" IS -- so this prints what the compiler produced, not only
# whether it stopped.  And section 4 again: a stamp, so a truncated run cannot
# read as a pass.
#
# usage: t163-select.sh <builddir>
D=${1:?build dir}
CC1=$D/gcc/cc1
[ -x "$CC1" ] || { echo "FATAL: no cc1 at $CC1"; exit 9; }
[ -f "$D/t163.rc" ] || { echo "FATAL: $D has no build stamp"; exit 9; }
[ "$(cat "$D/t163.rc")" = 0 ] || { echo "FATAL: build stamp is not 0"; exit 9; }

W=$D/sel; rm -rf $W; mkdir -p $W
printf 'int f(int a){return a+1;}\n' > $W/t.c

# The canonical spellings the build dir uses, NOT the typed ones -- see
# t170-bases11.txt for why that distinction has bitten a harness before.
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu xstormy16-unknown-elf; do
  printf 'target %s\n' "$t" > $W/tc-$t
  "$CC1" -quiet -nostdinc -ftarget-config=$W/tc-$t $W/t.c -o $W/$t.s \
      > $W/$t.out 2> $W/$t.err
  rc=$?
  n=$(grep -c . "$W/$t.s" 2>/dev/null || echo 0)
  printf '%-30s rc=%-4s asm_lines=%-5s %s\n' "$t" "$rc" "$n" \
      "$(head -c 200 $W/$t.err | tr '\n' ' ')"
done
