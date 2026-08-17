#!/bin/sh
# Configure the 47-base multi-target build for this task.
#
# The list is the committed 47 (`/tmp/b-ae38239f92c500037-47.list', the same
# one A7D26223EEFCFA725-BOARD.md used) with ONE substitution, which is the
# whole point of this task and is therefore stated rather than buried:
#
#     arm-eabi  ->  arm-linux-gnueabihf
#
# `arm-eabi' canonicalises to `arm-unknown-eabi', a bare-metal target with no
# glibc and therefore no stock control that resembles the four LP64 rows.
# `arm-linux-gnueabihf' canonicalises to `arm-unknown-linux-gnueabihf' and is
# built from the same materials as aarch64/riscv64/s390x/x86_64: real cross
# binutils 2.46 and the target's own glibc headers.  It is still the `arm' back
# end -- the same 47 bases go into the binary either way.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC}
D=${1:?build dir}
LIST=aarch64-unknown-linux-gnu,alpha-linux-gnu,arc-elf32,arm-linux-gnueabihf,avr-elf,bfin-elf,bpf-unknown-none,c6x-elf,cris-elf,csky-elf,epiphany-elf,fr30-elf,frv-elf,ft32-elf,amdgcn-amdhsa,h8300-elf,x86_64-pc-linux-gnu,ia64-elf,iq2000-elf,lm32-elf,m32r-elf,m68k-elf,mcore-elf,microblaze-elf,mips64-elf,mmix-knuth-mmixware,mn10300-elf,moxie-elf,msp430-elf,nds32be-elf,nvptx-none,or1k-elf,hppa64-linux-gnu,pdp11-aout,pru-elf,riscv64-unknown-linux-gnu,rl78-elf,powerpc64-linux-gnu,rx-elf,s390x-linux-gnu,sh-elf,sparc64-linux,v850e1-elf,vax-linux-gnu,visium-elf,xstormy16-elf,xtensa-elf
n=$(printf '%s\n' "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: list has $n entries, not 47"; exit 9; }
printf '%s' "$LIST" | tr ',' '\n' | grep -qx arm-linux-gnueabihf \
  || { echo "FATAL: the arm entry is not the linux-gnueabihf one"; exit 9; }
exec env SRC="$SRC" WANT_ANCHOR=55 sh "$S/mt-conf.sh" "$D" "$LIST"
