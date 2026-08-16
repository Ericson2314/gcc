#!/bin/sh
# Build a real GNU cross `as' for every back end the nixpkgs route could not
# describe.  See agent-acda89931a903ec27-gasbuild.sh for why this route exists
# and why it is the legitimate `--target'.
#
# The triples are gcc's own, from A7EE6CA7C923E4A58-STAGE1-TABLE.txt, so the
# resulting `<triple>-as' is named the way target-specs will look for it.
SRC=${SRC:?binutils source}
OUT=${OUT:?output bin dir}
HERE=$(dirname "$0")
mkdir -p "$OUT"
for t in \
  bfin-unknown-elf bpf-unknown-none cris-axis-elf csky-unknown-elf \
  epiphany-unknown-elf fr30-unknown-elf frv-unknown-elf ft32-unknown-elf \
  h8300-unknown-elf hppa64-unknown-linux-gnu ia64-unknown-elf \
  iq2000-unknown-elf lm32-unknown-elf m32r-unknown-elf mcore-unknown-elf \
  mn10300-unknown-elf moxie-unknown-elf nds32be-unknown-elf \
  pdp11-dec-aout pru-unknown-elf rl78-unknown-elf tic6x-unknown-elf \
  v850e1-unknown-elf vax-dec-linux-gnu visium-unknown-elf \
  xstormy16-unknown-elf xtensa-unknown-elf ; do
  SRC="$SRC" sh "$HERE/agent-acda89931a903ec27-gasbuild.sh" "$t" "$OUT" 2>&1 | head -3
done
echo "=== built:"; ls "$OUT" | wc -l
