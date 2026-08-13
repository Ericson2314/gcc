#!/bin/sh
# #131 -- ASSEMBLE AND DISASSEMBLE the aarch64 output with a REAL aarch64
# assembler, and read the UNWIND TABLE back out of the object.
#
# "It compiled" is not the measurement; #127's wall "moved" once by turning
# into `str x19, [x7, -32]!' -- i386's regnums used as aarch64's -- and exited
# 0.  So: the instructions must disassemble to aarch64 machine code that
# implements `a + 1', AND `readelf --debug-dump=frames' must show a CFA that
# starts at sp+0.
#
# NON-VACUITY: the assembler and objdump must be the aarch64 ones.  A missing
# tool piped into a grep scores 0 in the direction that makes the reference
# look correct, so the tools are named and asserted first.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b134}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
IN=${1:-$B/after-add-aarch64-unknown-linux-gnu.s}
[ -s "$IN" ] || { echo "FATAL: no input assembly $IN"; exit 9; }

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    echo '--- tools (must be the aarch64 ones, not the build machine s):'
    command -v aarch64-unknown-linux-gnu-as
    command -v aarch64-unknown-linux-gnu-objdump
    command -v aarch64-unknown-linux-gnu-readelf
    echo '--- assembling:'
    aarch64-unknown-linux-gnu-as -o $B/t134-add.o $IN
    echo '--- file type (must say aarch64):'
    aarch64-unknown-linux-gnu-readelf -h $B/t134-add.o | grep Machine
    echo '--- disassembly:'
    aarch64-unknown-linux-gnu-objdump -d $B/t134-add.o
    echo '--- unwind table, decoded from the assembled object:'
    aarch64-unknown-linux-gnu-readelf --debug-dump=frames $B/t134-add.o
  "
echo "rc=$?"
