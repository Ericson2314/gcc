#!/bin/sh
# Materialise the arm cross assembler/linker and arm glibc headers, in the SAME
# shape taa-tools.sh produces for the four LP64 targets, so sc-conf.sh and
# taa-specs.sh can consume them without a special case.
#
# WHY `arm-unknown-linux-gnueabihf' AND NOT THE BOARD'S `arm-unknown-eabi':
# the four scored targets are all *-linux-gnu with the target's own glibc
# headers, and the whole stock control recipe (sc-conf.sh) is built on
# --with-sysroot=<glibc.dev> + --with-native-system-header-dir=/include.  A
# bare-metal `arm-unknown-eabi' has no glibc at all, so a control for it would
# either have no system headers (the 66,883-diagnostic floor SC-BOARD.md §0
# records) or would need a newlib recipe no other row uses.  The substitution
# is DELIBERATE and is reported with the row.
#
# The nixpkgs prefix is `armv7l-unknown-linux-gnueabihf-'; config.sub
# canonicalises `arm-linux-gnueabihf' to `arm-unknown-linux-gnueabihf'.  Same
# binutils, different name -- exactly the s390x naming trap taa-tools.sh
# records -- so the shims are renames of the real cross tools, NEVER a
# fallback to the host's `as'.
set -e
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"
OUT=${1:?output dir}
mkdir -p "$OUT" "$OUT/bin"
canon=arm-unknown-linux-gnueabihf
attr=armv7l-hf-multiplatform

bu=$(nix-build $NIXOPT --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A "pkgsCross.$attr.buildPackages.binutils")
hd=$(nix-build $NIXOPT --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A "pkgsCross.$attr.stdenv.cc.libc.dev")
echo "$canon binutils=$bu headers=$hd"
pfx=$(ls "$bu/bin" | sed -n 's/-as$//p' | head -1)
[ -n "$pfx" ] || { echo "FATAL: no *-as in $bu/bin"; exit 9; }
echo "-- nixpkgs prefix: $pfx"
for t in as ld nm ar ranlib objdump objcopy strip readelf; do
  [ -x "$bu/bin/$pfx-$t" ] || continue
  ln -sf "$bu/bin/$pfx-$t" "$OUT/bin/$canon-$t"
done
[ -x "$OUT/bin/$canon-as" ] || { echo "FATAL: no $canon-as shim"; exit 9; }
# `OK' must mean the binary EXECUTED, not that a path exists (INSTRUMENTS.md):
# a dangling symlink or a wrong-arch binary is precisely what falls back to the
# host `as' three layers away.
"$OUT/bin/$canon-as" --version | head -1
[ -d "$hd/include" ] || { echo "FATAL: no $hd/include"; exit 9; }
echo "$hd/include" > "$OUT/$canon.hdr"
# The headers must be the TARGET's.  A wrong-arch glibc.dev would still have an
# include/ and would still pass a `-d' test, so read a header that names the
# machine.
grep -q '__ARM_PCS_VFP' "$hd/include/gnu/stubs.h" \
  || { echo "FATAL: $hd/include/gnu/stubs.h does not dispatch on __ARM_PCS_VFP;"
       echo "  these are not the arm hard-float glibc headers"; exit 9; }
# AND THE FLOOR THIS SET CARRIES, RECORDED HERE RATHER THAN DISCOVERED LATER:
# only `stubs-hard.h' exists -- there is no `stubs-soft.h'.  A compiler whose
# default float ABI is SOFT therefore dies in <features.h> on every TU, which
# is SC-BOARD.md §0's missing-header floor exactly.  sc-check.sh's guard S3
# compiles a real TU, so it fires; this is the note that says what it means.
[ -f "$hd/include/gnu/stubs-hard.h" ] || { echo "FATAL: no stubs-hard.h"; exit 9; }
[ -f "$hd/include/gnu/stubs-soft.h" ] \
  && echo "-- note: stubs-soft.h present too" \
  || echo "-- NOTE: NO stubs-soft.h; the target MUST default to -mfloat-abi=hard"
ls "$hd/include/gnu/" | head
echo "-- shims:"; ls "$OUT/bin"
