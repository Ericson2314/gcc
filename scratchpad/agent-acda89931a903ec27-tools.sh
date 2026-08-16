#!/bin/sh
# Assemble ONE tools dir holding a verified cross toolchain for all 45 back
# ends that can have one, named by GCC'S OWN TRIPLE (what target-specs looks
# for).  Three sources, and every entry is re-verified by ARM 4 afterwards --
# including the inherited ones.  PRINCIPLES: "in a shared build dir, a file
# you did not write is not a fixture."  The inherited directory belongs to
# another worktree and contains, among other things, a LITTLE-endian
# powerpc64le assembler; nothing may be trusted here on provenance alone.
#
#   1. /tmp/gasbin-<id>          27 built by agent-acda89931a903ec27-gasbuild.sh
#   2. $INHERIT/bin              17 from the nixpkgs route (another worktree)
#   3. $PPC                      powerpc64 big-endian, gnuabielfv2 spelling
#
# nvptx and gcn are deliberately ABSENT: they have no GNU assembler in the
# concept.  That is NOT-APPLICABLE, a third verdict, and it must not be
# supplied by a stand-in.
set -eu
OUT=${OUT:?output dir}
MINE=${MINE:-/tmp/gasbin-agent-acda89931a903ec27}
INHERIT=${INHERIT:-/tmp/tools-a7ee6ca7c923e4a58/bin}
PPC=${PPC:?powerpc64 big-endian binutils bin dir}

rm -rf "$OUT"; mkdir -p "$OUT"

# --- 1. mine -------------------------------------------------------------
n1=0
for f in "$MINE"/*-as; do
  [ -x "$f" ] || continue
  cp "$f" "$OUT/$(basename "$f")"; n1=$((n1+1))
done

# --- 2. inherited, ONLY under gcc's own triple spellings ------------------
# Listed explicitly rather than globbed: the inherited dir carries both
# `alpha-linux-gnu-as' and `alpha-unknown-linux-gnu-as', and a glob would
# install both, leaving which one answers to directory order.
n2=0
for t in aarch64-unknown-linux-gnu alpha-unknown-linux-gnu arc-unknown-elf32 \
         arm-unknown-eabi avr-unknown-elf m68k-unknown-elf \
         microblaze-xilinx-elf mips64-unknown-elf mmix-knuth-mmixware \
         msp430-unknown-elf or1k-unknown-elf riscv64-unknown-linux-gnu \
         rx-unknown-elf s390x-ibm-linux-gnu sh-unknown-elf \
         sparc64-unknown-linux-gnu x86_64-pc-linux-gnu ; do
  s="$INHERIT/$t-as"
  [ -e "$s" ] || { echo "MISSING-INHERITED $t"; continue; }
  cp -L "$s" "$OUT/$t-as"; n2=$((n2+1))
  for u in ld nm ar ranlib objdump objcopy strip readelf; do
    [ -e "$INHERIT/$t-$u" ] && cp -L "$INHERIT/$t-$u" "$OUT/$t-$u" || true
  done
done

# --- 3. powerpc64 BIG endian, under gcc's triple --------------------------
p=$(ls "$PPC"/*-as 2>/dev/null | head -1)
[ -n "$p" ] || { echo "FATAL: no *-as in $PPC"; exit 9; }
cp -L "$p" "$OUT/powerpc64-unknown-linux-gnu-as"
for u in ld nm ar ranlib objdump objcopy strip readelf; do
  q=$(ls "$PPC"/*-"$u" 2>/dev/null | head -1)
  [ -n "$q" ] && cp -L "$q" "$OUT/powerpc64-unknown-linux-gnu-$u" || true
done

echo "mine=$n1 inherited=$n2 ppc=1 total=$(ls "$OUT" | grep -c -- '-as$')"
