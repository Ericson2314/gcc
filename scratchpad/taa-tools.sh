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
set -e
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
OUT=${1:?output dir}
mkdir -p "$OUT" "$OUT/bin"
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
