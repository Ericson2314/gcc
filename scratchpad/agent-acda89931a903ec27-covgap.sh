#!/bin/sh
# Which of the 47 back ends have NO `scan-assembler'-on-`dg-do compile'
# coverage at all?
#
# The back-end list is gcc's own `cpu_type' set, taken from the Stage 1 table
# so the two documents cannot drift.  The directory name under gcc.target is
# NOT always the back-end name -- rs6000's tests live in `powerpc/', pa's in
# `hppa/', c6x's in `tic6x/', i386's are split across `i386/' and `x86_64/'.
# A census keyed on the back-end name alone scores four back ends as having
# zero tests when they have thousands, which is the wrong direction for a
# number that authorises writing new tests.
set -u
T=${1:-gcc/testsuite}

# backend:dir[,dir...]     dir empty => no upstream directory exists
MAP="aarch64:aarch64 alpha:alpha arc:arc arm:arm avr:avr bfin:bfin bpf:bpf
cris:cris csky:csky epiphany:epiphany fr30: frv:frv ft32: gcn:gcn h8300:h8300
i386:i386,x86_64 ia64:ia64 iq2000: lm32: m32r: m68k:m68k mcore:
microblaze:microblaze mips:mips mmix: mn10300: moxie: msp430:msp430
nds32:nds32 nvptx:nvptx or1k:or1k pa:hppa pdp11:pdp11 pru:pru
riscv:riscv rl78:rl78 rs6000:powerpc rx:rx s390:s390 sh:sh sparc:sparc
c6x:tic6x v850:v850 vax:vax visium:visium xstormy16:xstormy16 xtensa:xtensa"

n=0; nzero=0; nlow=0
for e in $MAP; do
  be=${e%%:*}; dirs=${e#*:}
  n=$((n+1))
  tot=0
  if [ -n "$dirs" ]; then
    for d in $(echo "$dirs" | tr ',' ' '); do
      [ -d "$T/gcc.target/$d" ] || continue
      c=$(find "$T/gcc.target/$d" -type f -name '*.c' \
          -exec grep -l 'scan-assembler' {} + 2>/dev/null | wc -l)
      tot=$((tot+c))
    done
  fi
  if [ -z "$dirs" ]; then
    printf '%-12s %6s   NO UPSTREAM DIRECTORY\n' "$be" 0; nzero=$((nzero+1))
  elif [ "$tot" -eq 0 ]; then
    printf '%-12s %6d   dir exists, zero scan-assembler\n' "$be" "$tot"; nzero=$((nzero+1))
  elif [ "$tot" -lt 20 ]; then
    printf '%-12s %6d   LOW\n' "$be" "$tot"; nlow=$((nlow+1))
  else
    printf '%-12s %6d\n' "$be" "$tot"
  fi
done
echo
echo "back ends: $n   with NO coverage: $nzero   with <20: $nlow"
[ "$n" -eq 47 ] || { echo "FATAL: back-end list is $n, not 47"; exit 9; }
