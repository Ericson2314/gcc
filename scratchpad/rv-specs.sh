#!/bin/sh
# `make target-specs' with the cross-assembler wrappers on PATH.
#
# Without them the rule SKIPs aarch64 -- writing NO specs-<target>-config file
# at all -- and the next thing seen is cc1's
# `common target hook option_init_struct was used before a target was
# selected', which points nowhere near the cause.  See DEVSHELL.md.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b-rv59}
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && PATH=/tmp/mt-fakebin:\$PATH make target-specs"
