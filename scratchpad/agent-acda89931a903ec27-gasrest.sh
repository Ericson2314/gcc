#!/bin/sh
# The other 18 back ends' assemblers, built from the SAME binutils source as
# the first 27, so all 45 share one provenance and one version.
#
# WHY NOT REUSE THE NIXPKGS ONES.  Measured: every symlink in
# /tmp/tools-a7ee6ca7c923e4a58/bin is DANGLING -- the store paths were built
# with `--no-out-link' and have been garbage-collected.  A dangling
# `<triple>-as' is precisely the shape that falls back to the host assembler
# three layers away (GUARD 3c, ~10,000 results per target), and `ls' shows the
# names perfectly happily.  Building from source removes the GC dependency
# entirely and gives one version across all 45 rather than two provenances.
#
# nvptx and gcn are absent by design: NOT-APPLICABLE, not "not built".
SRC=${SRC:?binutils source}
OUT=${OUT:?output bin dir}
HERE=$(dirname "$0")
mkdir -p "$OUT"
for t in \
  aarch64-unknown-linux-gnu alpha-unknown-linux-gnu arc-unknown-elf32 \
  arm-unknown-eabi avr-unknown-elf m68k-unknown-elf \
  microblaze-xilinx-elf mips64-unknown-elf mmix-knuth-mmixware \
  msp430-unknown-elf or1k-unknown-elf powerpc64-unknown-linux-gnu \
  riscv64-unknown-linux-gnu rx-unknown-elf s390x-ibm-linux-gnu \
  sh-unknown-elf sparc64-unknown-linux-gnu x86_64-pc-linux-gnu ; do
  [ -x "$OUT/$t-as" ] && { echo "$t ALREADY"; continue; }
  SRC="$SRC" sh "$HERE/agent-acda89931a903ec27-gasbuild.sh" "$t" "$OUT" 2>&1 | head -3
done
echo "=== total -as: $(ls "$OUT" | grep -c -- '-as$')"
