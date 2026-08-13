#!/bin/sh
# Build shell PLUS gdb.  `gdb' is not in the plain DEVSHELL package set, and a
# missing tool piped into a grep scores 0 in the direction that makes the
# reference look correct (PRINCIPLES section 5), so it gets its own wrapper
# rather than being added ad hoc at each call site.
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
exec nix-shell -I "nixpkgs=$HOME/src/nixos-configuration/dep/nixpkgs" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo gdb \
  --substituters 'https://cache.nixos.org/' \
  --run "$*"
