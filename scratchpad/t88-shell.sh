#!/bin/sh
# The DEVSHELL "build" shell, byte-identical -p set to the known-cached one.
#   t88-shell.sh '<command>'
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
exec nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "export NIX_HARDENING_ENABLE='fortify stackprotector pic strictoverflow relro bindnow'; $1"
