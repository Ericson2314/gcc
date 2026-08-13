#!/bin/sh
# Full build shell per DEVSHELL.md.  $* = command to run inside it.
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
exec nix-shell -I "nixpkgs=$HOME/src/nixos-configuration/dep/nixpkgs" \
  -p gcc gdb gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "$*"
