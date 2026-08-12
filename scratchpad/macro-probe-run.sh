#!/usr/bin/env bash
# Wrapper: macro-probe.sh needs a host g++, binutils and the headers gcc's
# system.h pulls in (gmp above all -- a missing gmp.h is the DEVSHELL trap that
# makes probes fail for a reason unrelated to what they measure).
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HERE=$(cd "$(dirname "$0")" && pwd)
exec nix-shell -I "nixpkgs=$NP" \
  -p gcc binutils gmp.dev mpfr.dev libmpc gawk gnused coreutils diffutils \
  --substituters 'https://cache.nixos.org/' \
  --run "export NIX_HARDENING_ENABLE=; OUT=${OUT:-/tmp/mtp-out} bash $HERE/macro-probe.sh $*"
