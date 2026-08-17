#!/bin/sh
# Configure the 47-base multi-target build for the i686 row.
#
# The list is the committed 47 (as `a660907426e03e4e9-conf47.sh' records it)
# with TWO substitutions, both stated rather than buried:
#
#     arm-eabi             ->  arm-linux-gnueabihf   (inherited from the arm
#                                                     row; the same back end)
#     x86_64-pc-linux-gnu  ->  i686-unknown-linux-gnu
#
# THE SECOND SUBSTITUTION IS FORCED, AND WHY IT IS FORCED IS ITSELF A RESULT.
# The obvious move -- ADD i686 as a 48th base and keep x86_64 -- configures
# cleanly and is WRONG, silently.  `gen-target-manifest.sh' keys the
# per-back-end artefacts on cpu_type behind
#
#     case " ${gcc_all_cpu_bases} " in *" ${gcc_mt_cpu} "*) ;;
#
# so the FIRST triple of a back end wins `tm-<cpu>.h', and every later triple
# of that back end contributes nothing to it and gets no diagnostic.  With
# both x86_64 and i686 configured, `i686-unknown-linux-gnu' sorts first, so
# `tm-i386.h' -- the header `i386-common.o', `spec-functions-i386.o' and
# `target-asm-ops-i386.o' are compiled against -- is built from the i686
# chain (no `i386/biarch64.h', no `i386/x86-64.h', no `i386/linux64.h').
# MEASURED in /tmp/b-af2bdad90c8ebe685-probe; see the board.
#
# One triple per back end therefore keeps this row a measurement of i686
# rather than a measurement of that collision.  The collision is scored
# separately.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC}
D=${1:?build dir}
LIST=aarch64-unknown-linux-gnu,alpha-linux-gnu,arc-elf32,arm-linux-gnueabihf,avr-elf,bfin-elf,bpf-unknown-none,c6x-elf,cris-elf,csky-elf,epiphany-elf,fr30-elf,frv-elf,ft32-elf,amdgcn-amdhsa,h8300-elf,i686-unknown-linux-gnu,ia64-elf,iq2000-elf,lm32-elf,m32r-elf,m68k-elf,mcore-elf,microblaze-elf,mips64-elf,mmix-knuth-mmixware,mn10300-elf,moxie-elf,msp430-elf,nds32be-elf,nvptx-none,or1k-elf,hppa64-linux-gnu,pdp11-aout,pru-elf,riscv64-unknown-linux-gnu,rl78-elf,powerpc64-linux-gnu,rx-elf,s390x-linux-gnu,sh-elf,sparc64-linux,v850e1-elf,vax-linux-gnu,visium-elf,xstormy16-elf,xtensa-elf
n=$(printf '%s\n' "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: list has $n entries, not 47"; exit 9; }
printf '%s' "$LIST" | tr ',' '\n' | grep -qx i686-unknown-linux-gnu \
  || { echo "FATAL: the i386 entry is not the i686 one"; exit 9; }
printf '%s' "$LIST" | tr ',' '\n' | grep -q x86_64 \
  && { echo "FATAL: x86_64 is still in the list; two i386 triples collide in tm-i386.h"; exit 9; }
exec env SRC="$SRC" WANT_ANCHOR=55 sh "$S/mt-conf.sh" "$D" "$LIST"
