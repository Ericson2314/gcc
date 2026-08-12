#!/usr/bin/env bash
# Wrapper for tab-probe.sh.  Same -p set as macro-probe-run.sh, byte for byte:
# extending a cached nix-shell -p line has cost this project a twenty-minute
# LLVM build before now.
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HERE=$(cd "$(dirname "$0")" && pwd)
exec nix-shell -I "nixpkgs=$NP" \
  -p gcc binutils gmp.dev mpfr.dev libmpc gawk gnused coreutils diffutils \
  --substituters 'https://cache.nixos.org/' \
  --run "export NIX_HARDENING_ENABLE=; OUT=${OUT:-/tmp/tab-out} MTP=${MTP:-/tmp/mtp-before} bash $HERE/tab-probe.sh $*"
