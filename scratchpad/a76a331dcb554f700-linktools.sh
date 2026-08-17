#!/bin/sh
# a76a331dcb554f700 -- alias the freshly built cross tools under the CANONICAL
# triple names this build dir uses.
#
# nixpkgs cannot describe `m68k-unknown-elf', `msp430-unknown-elf',
# `microblaze-xilinx-elf', `rx-unknown-elf' or `sh-unknown-elf' -- an
# EVAL-FAIL, i.e. a statement about `lib.systems.parse', NOT about binutils --
# but it CAN describe `m68k-elf', `msp430-elf', `microblaze-elf', `rx-elf' and
# `sh4-elf', and those produce the same GNU `as' for the same machine.  The
# aliasing is therefore between two spellings of one target, not between two
# targets, and each pair is written out here so the substitution is visible in
# the file rather than buried in a loop.
#
# sh4-elf FOR sh-unknown-elf IS THE ONE PAIR THAT IS NOT MERELY A RESPELLING:
# it selects a default CPU.  `as' accepts the full SH instruction set and
# rejects by insn, so it is usable for a compile-and-assemble census, but a
# row scored with it must say so.  Marked SUBSTITUTED below.
set -eu
OUT=${1:?output dir}
mkdir -p "$OUT"
link () {
  src=$1; dst=$2
  [ -x "$src" ] || { echo "FATAL: no $src"; exit 9; }
  "$src" --version 2>/dev/null | head -1 | grep -q "GNU assembler" \
    || { echo "FATAL: $src does not execute"; exit 9; }
  ln -sf "$(readlink -f "$src")" "$OUT/$dst"
  echo "aliased $dst -> $src"
}
A=/tmp/tools8b-a76a331dcb554f700/bin
B=/tmp/tools8-a76a331dcb554f700/bin
link "$A/m68k-elf-as"       m68k-unknown-elf-as
link "$A/microblaze-elf-as" microblaze-xilinx-elf-as
link "$A/msp430-elf-as"     msp430-unknown-elf-as
link "$A/rx-elf-as"         rx-unknown-elf-as
link "$A/sh4-elf-as"        sh-unknown-elf-as          # SUBSTITUTED, see above
link "$B/mmix-knuth-mmixware-as" mmix-knuth-mmixware-as
link "$B/sparc64-unknown-linux-gnu-as" sparc64-unknown-linux-gnu-as
echo
echo "NOTE: powerpc64-unknown-linux-gnu has NO working as here -- EVAL-FAIL"
echo "      under both spellings tried.  Reported as AS-ABSENT, never scored"
echo "      against the host as."
