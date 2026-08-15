#!/bin/sh
# Materialise, for each candidate target, (a) a real cross assembler+linker and
# (b) that target's OWN glibc headers.  Both are per-target facts: a single
# shared header dir would be one machine's answer served to every target, which
# is the shape this branch exists to delete (PRINCIPLES 2).
#
# NAMING TRAP, MEASURED: nixpkgs names s390x binutils `s390x-unknown-linux-gnu-*'
# while config.sub canonicalises the same target to `s390x-ibm-linux-gnu', and
# target-specs looks the tools up by the CANONICAL name.  Without a shim it
# SKIPs, and the symptom surfaces three layers away as "no specs-config".  The
# shim is a rename of the real cross tool, never a fallback to the host's `as'.
#
# x86_64 IS HERE TOO, AND IT IS NOT A SPECIAL CASE TO SKIP.  Until now this
# file served the three genuine crosses and left x86_64 to whatever the build
# dir resolved -- which is the same "the host answers for the target" shape the
# cross entries exist to remove, and it is invisible precisely BECAUSE the host
# happens to be x86_64.  A stock x86_64 control needs `x86_64-pc-linux-gnu-as'
# by that name, and a multi-target x86_64 run should reach its assembler
# through the same named path as every other target rather than through a
# fallback.  The tools are `binutils-unwrapped', the SAME 2.46 the pkgsCross
# entries resolve to (measured: both are `*-binutils-2.46'), and the headers
# are `glibc.dev', the same store path mt-conf.sh names as MT_HDR -- so the
# x86_64 row is built from the same materials as the other three rather than
# from the host's ambient environment.
set -e
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
OUT=${1:?output dir}
mkdir -p "$OUT" "$OUT/bin"

# ---- the native target.  Attr paths differ (no pkgsCross), so it is its own
# ---- block rather than a case inside the loop below.
nbu=$(nix-build --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A binutils-unwrapped)
nhd=$(nix-build --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A glibc.dev)
ncanon=x86_64-pc-linux-gnu
echo "$ncanon binutils=$nbu headers=$nhd"
[ -x "$nbu/bin/as" ] || { echo "FATAL: no $nbu/bin/as"; exit 9; }
for t in as ld nm ar ranlib objdump objcopy strip readelf; do
  [ -x "$nbu/bin/$t" ] || continue
  ln -sf "$nbu/bin/$t" "$OUT/bin/$ncanon-$t"
done
[ -x "$OUT/bin/$ncanon-as" ] || { echo "FATAL: no $ncanon-as shim"; exit 9; }
[ -d "$nhd/include" ] || { echo "FATAL: no $nhd/include"; exit 9; }
echo "$nhd/include" > "$OUT/$ncanon.hdr"

for spec in \
  "aarch64-multiplatform aarch64-unknown-linux-gnu" \
  "riscv64 riscv64-unknown-linux-gnu" \
  "s390x s390x-ibm-linux-gnu"
do
  set -- $spec
  attr=$1; canon=$2
  bu=$(nix-build --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A "pkgsCross.$attr.buildPackages.binutils")
  hd=$(nix-build --no-out-link -I "nixpkgs=$NP" '<nixpkgs>' -A "pkgsCross.$attr.stdenv.cc.libc.dev")
  echo "$canon binutils=$bu headers=$hd"
  # assert the real tool exists before shimming; a dangling link would make the
  # probe fall back to the host tools with no diagnostic.
  pfx=$(ls "$bu/bin" | sed -n 's/-as$//p' | head -1)
  [ -n "$pfx" ] || { echo "FATAL: no *-as in $bu/bin"; exit 9; }
  for t in as ld nm ar ranlib objdump objcopy strip readelf; do
    [ -x "$bu/bin/$pfx-$t" ] || continue
    ln -sf "$bu/bin/$pfx-$t" "$OUT/bin/$canon-$t"
  done
  [ -x "$OUT/bin/$canon-as" ] || { echo "FATAL: no $canon-as shim"; exit 9; }
  [ -d "$hd/include" ] || { echo "FATAL: no $hd/include"; exit 9; }
  echo "$hd/include" > "$OUT/$canon.hdr"
done
echo "-- shims:"
ls "$OUT/bin"
