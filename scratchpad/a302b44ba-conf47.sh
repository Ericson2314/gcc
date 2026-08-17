#!/bin/sh
# The canonical 47 for task #241's RE-TAKE, with `x86_64-pc-linux-gnu' in the
# i386 slot.
#
# This is `af2bdad90c8ebe685-conf47.sh' with its ONE substitution inverted.
# That script put `i686-unknown-linux-gnu' in the i386 slot and REFUSED if
# x86_64 was also present, because `gen-target-manifest.sh' dedups on
# `cpu_type': two triples of one back end silently give the whole back end the
# first triple's headers (AF2BDAD90C8EBE685-I686-BOARD.md 4, now refused by
# name in 907985867f3).  The same hazard applies here with the sign flipped,
# so the same refusal is written the other way round.
#
# `arm-linux-gnueabihf' rather than `arm-eabi' is INHERITED from the arm and
# i686 rows: it is the arm triple for which real cross binutils and a real
# glibc exist, so an arm figure taken here is not a figure about a shim.
#
# The four targets this row must score -- x86_64, aarch64, s390x, i686 -- are
# the four the manifest gives `decimal_float 1'.  Three of them are in THIS
# list; i686 cannot be, for the cpu_type reason above, and is why the i686 row
# is a separate build and is reported from the one af2bdad90c8ebe685 took.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC}
D=${1:?build dir}

LIST=aarch64-unknown-linux-gnu,alpha-linux-gnu,arc-elf32,arm-linux-gnueabihf,avr-elf,bfin-elf,bpf-unknown-none,c6x-elf,cris-elf,csky-elf,epiphany-elf,fr30-elf,frv-elf,ft32-elf,amdgcn-amdhsa,h8300-elf,x86_64-pc-linux-gnu,ia64-elf,iq2000-elf,lm32-elf,m32r-elf,m68k-elf,mcore-elf,microblaze-elf,mips64-elf,mmix-knuth-mmixware,mn10300-elf,moxie-elf,msp430-elf,nds32be-elf,nvptx-none,or1k-elf,hppa64-linux-gnu,pdp11-aout,pru-elf,riscv64-unknown-linux-gnu,rl78-elf,powerpc64-linux-gnu,rx-elf,s390x-linux-gnu,sh-elf,sparc64-linux,v850e1-elf,vax-linux-gnu,visium-elf,xstormy16-elf,xtensa-elf

n=$(printf '%s\n' "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: list has $n entries, not 47"; exit 9; }

# BOTH ARMS OF THE i386-SLOT REFUSAL, so that neither "x86_64 quietly missing"
# nor "both i386 triples present" can reach a board.
printf '%s' "$LIST" | tr ',' '\n' | grep -qx x86_64-pc-linux-gnu \
  || { echo "FATAL: the i386 entry is not the x86_64 one"; exit 9; }
# NOTE the `if', not `A && { ... }'.  Under `set -e' the `&&' form is the LAST
# command of the list, so when the grep does not match -- i.e. when the check
# PASSES -- the list returns 1 and the shell exits 1 with no message.  The
# af2bdad90c8ebe685 copy of this file has that shape; it survived only because
# its grep did match.  A guard whose passing arm aborts the script is the
# false-green family, so it is written as an `if'.
if printf '%s' "$LIST" | tr ',' '\n' | grep -q 'i[36]86'; then
  echo "FATAL: an i?86 triple is still in the list; two i386 triples collide in tm-i386.h"; exit 9
fi

# The three targets this build must be able to score, named rather than assumed.
for t in aarch64-unknown-linux-gnu s390x-linux-gnu riscv64-unknown-linux-gnu; do
  printf '%s' "$LIST" | tr ',' '\n' | grep -qx "$t" \
    || { echo "FATAL: $t is not in the list; this build cannot score it"; exit 9; }
done

exec env SRC="$SRC" WANT_ANCHOR=55 sh "$S/mt-conf.sh" "$D" "$LIST"
