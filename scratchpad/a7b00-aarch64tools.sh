#!/bin/sh
# a7b00eeb03e7b153b -- materialise the aarch64 cross binutils and glibc headers,
# in the same shape a660907426e03e4e9-armtools.sh produces for arm.
#
# The shims are RENAMES of the real cross tools (nixpkgs prefixes them
# `aarch64-unknown-linux-gnu-' already, so mostly a straight symlink).  NEVER a
# fallback to the host `as': `OK' below means the binary EXECUTED and named the
# architecture, not that a path exists.
set -e
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"
OUT=${1:?output dir}
mkdir -p "$OUT/bin"
canon=aarch64-unknown-linux-gnu
attr=aarch64-multiplatform

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
v=$("$OUT/bin/$canon-as" --version 2>&1 | head -1)
case "$v" in
  *"GNU assembler"*) echo "as OK: $v" ;;
  *) echo "FATAL: $canon-as did not run: $v"; exit 9 ;;
esac
# NON-VACUITY: it must be the AARCH64 assembler, not the host's under a name.
printf 'f: ret\n' > "$OUT/probe.s"
"$OUT/bin/$canon-as" -o "$OUT/probe.o" "$OUT/probe.s"
m=$("$OUT/bin/$canon-readelf" -h "$OUT/probe.o" | sed -n 's/.*Machine: *//p')
echo "assembled machine: $m"
case "$m" in
  *AArch64*) ;;
  *) echo "FATAL: assembled to $m, not AArch64 -- this is the host as"; exit 9 ;;
esac
echo "$hd" > "$OUT/HEADERS"
echo "headers: $hd"
