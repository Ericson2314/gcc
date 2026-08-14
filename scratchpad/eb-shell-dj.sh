#!/bin/sh
# Build shell per DEVSHELL.md, PLUS dejagnu and expect.  $* = command to run.
#
# THE TESTSUITE HAS NEVER RUN ON THIS BRANCH AND THIS IS ONE REASON WHY:
# `runtest', `expect' and `tclsh' are ALL absent from the eb-shell.sh dev
# shell.  A missing runtest is not a quiet degradation -- make's check-% rule
# runs $(RUNTEST), which falls back to the literal string `runtest', and the
# recipe is wrapped in `-(...)' so make IGNORES the failure.  `make check-gcc'
# therefore exits 0 having run nothing at all, which is the exact shape of the
# rc=9 dead harness (#133): an exit 0 that probed nothing.
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
exec nix-shell -I "nixpkgs=$HOME/src/nixos-configuration/dep/nixpkgs" \
  -p gcc gdb gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p dejagnu expect \
  --substituters 'https://cache.nixos.org/' \
  --run "$*"
