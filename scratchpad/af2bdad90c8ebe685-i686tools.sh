#!/bin/sh
# Materialise the i686 cross assembler/linker and i686 glibc headers, in the
# SAME shape a660907426e03e4e9-armtools.sh produces for arm and taa-tools.sh
# for the four LP64 targets, so sc-conf.sh and mt-specs can consume them with
# no special case.
#
# WHY `i686-unknown-linux-gnu':
#   * it is ILP32, and it is the SECOND ILP32 row this board has ever had;
#   * it is the i386 back end, which is the branch's leaked primary -- the
#     back end whose functions shared code calls by name
#     (`x86_output_aligned_bss' from `i386/gnu-user.h:87').  A 32-bit row on
#     THAT back end tests the leak on the axis the leak is most likely to be
#     wrong on: `ix86_cmodel', `TARGET_64BIT', `Pmode';
#   * nixpkgs `pkgsCross.gnu32' gives real binutils 2.46 and a real i686
#     glibc, so nothing here is a shim around the host `as'.  The nixpkgs
#     prefix is ALREADY `i686-unknown-linux-gnu-', and config.sub leaves that
#     triple alone (`i686-linux-gnu' would canonicalise to `i686-pc-linux-gnu'
#     instead -- a different directory name for the same machine, which is the
#     s390x/arm naming trap in its third form).  So the links below are
#     name-for-name, not renames.
set -e
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"
OUT=${1:?output dir}
mkdir -p "$OUT" "$OUT/bin"
canon=i686-unknown-linux-gnu
attr=gnu32

bu=$(nix-build $NIXOPT --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A "pkgsCross.$attr.buildPackages.binutils")
hd=$(nix-build $NIXOPT --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A "pkgsCross.$attr.stdenv.cc.libc.dev")
echo "$canon binutils=$bu headers=$hd"
pfx=$(ls "$bu/bin" | sed -n 's/-as$//p' | head -1)
[ -n "$pfx" ] || { echo "FATAL: no *-as in $bu/bin"; exit 9; }
echo "-- nixpkgs prefix: $pfx"
[ "$pfx" = "$canon" ] || echo "-- NOTE: prefix $pfx != canon $canon; the links below RENAME"
for t in as ld nm ar ranlib objdump objcopy strip readelf; do
  [ -x "$bu/bin/$pfx-$t" ] || continue
  ln -sf "$bu/bin/$pfx-$t" "$OUT/bin/$canon-$t"
done
[ -x "$OUT/bin/$canon-as" ] || { echo "FATAL: no $canon-as shim"; exit 9; }
# `OK' must mean the binary EXECUTED and TARGETS i386, not that a path exists.
# A dangling link or a wrong-arch binary is exactly what falls back to the
# host `as' three layers away -- and here the host IS an x86 assembler, so the
# usual "invalid -march" crash that exposes a fallback WOULD NOT FIRE.  This
# row therefore needs a stronger arm than the arm row did: assemble a real TU
# and read the ELF class back.
"$OUT/bin/$canon-as" --version | head -1
printf '\t.text\n\t.globl f\nf:\tret\n' > "$OUT/probe.s"
"$OUT/bin/$canon-as" "$OUT/probe.s" -o "$OUT/probe.o"
cls=$("$OUT/bin/$canon-readelf" -h "$OUT/probe.o" | sed -n 's/^ *Class: *//p')
mach=$("$OUT/bin/$canon-readelf" -h "$OUT/probe.o" | sed -n 's/^ *Machine: *//p')
echo "-- probe.o: Class=$cls Machine=$mach"
[ "$cls" = ELF32 ] || { echo "FATAL: assembler produced $cls, not ELF32 -- this is not a 32-bit assembler"; exit 9; }
case "$mach" in *80386*) ;; *) echo "FATAL: Machine=$mach is not Intel 80386"; exit 9 ;; esac

[ -d "$hd/include" ] || { echo "FATAL: no $hd/include"; exit 9; }
echo "$hd/include" > "$OUT/$canon.hdr"
# The headers must be the TARGET's.  A wrong-arch glibc.dev still has an
# include/ and still passes `-d'.
#
# AND THE OBVIOUS DISCRIMINATOR IS WRONG, MEASURED: `gnu/stubs.h' is the SAME
# file in the i686 and the x86_64 glibc -- it dispatches on __x86_64__,
# __LP64__ and __ILP32__ in both, because it is generated from one x86 source.
# A guard reading it would have rejected the correct headers (it did).  What
# actually differs is WHICH `stubs-NN.h' were installed beside it: the i686
# glibc ships ONLY `stubs-32.h'.
#
# THAT IS ALSO THIS ROW'S FLOOR, recorded here rather than discovered inside
# 200,000 test results: a compiler whose default is 64-bit resolves
# `#include <gnu/stubs.h>' to `stubs-64.h', which DOES NOT EXIST, and dies in
# <features.h> on every single TU -- the missing-header floor SC-BOARD.md 0
# records, arriving on the other axis.  The i686 row must default to -m32.
[ -f "$hd/include/gnu/stubs-32.h" ] \
  || { echo "FATAL: no gnu/stubs-32.h in $hd/include -- not the i686 glibc headers"; exit 9; }
[ -f "$hd/include/gnu/stubs-64.h" ] \
  && { echo "FATAL: gnu/stubs-64.h is present; this is the x86_64 glibc"; exit 9; }
grep -q '__x86_64__' "$hd/include/bits/wordsize.h" \
  || { echo "FATAL: $hd/include/bits/wordsize.h is not the x86 one"; exit 9; }
echo "-- headers OK: stubs-32.h only (no stubs-64.h); the target MUST default to -m32"
ls "$hd/include/gnu/"
echo "-- shims:"; ls "$OUT/bin"
