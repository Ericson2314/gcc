#!/bin/sh
# Re-run gcc/configure so that a changed gcc/Makefile.in reaches the build dir.
#
# TWO TRAPS, BOTH PAID FOR HERE.
#
# 1. gcc/Makefile has no rule depending on gcc/Makefile.in, so an edit there is
#    invisible to an incremental build.  It presents as a link error naming a
#    symbol whose object is sitting compiled in the build directory
#    (`undefined reference to target_cumargs_for' next to
#    target-cumargs-select.cc having never been compiled).
#
# 2. `$D/gcc/config.status' IS NOT GCC'S.  scratchpad/t106-ts.sh (and this
#    task's t107-ts.sh) run `target-specs/configure' with cwd `$D/gcc', which
#    OVERWRITES config.status with target-specs'.  Running it then reports
#    `invalid argument: Makefile' -- or, worse, silently reconfigures the wrong
#    package.  So this script does not use config.status at all; it removes
#    gcc/Makefile and lets the TOP LEVEL configure gcc again.
#
#    Consequence for ordering: run target-specs LAST, after any reconfigure.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b133}
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
rm -f "$D/gcc/Makefile"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' \
  --run "cd $D && make configure-gcc" || exit $?
[ -f "$D/gcc/Makefile" ] || { echo "FATAL: gcc/Makefile was not recreated"; exit 9; }
if grep -n 'define rlim_t' "$D/gcc/auto-host.h"; then
  echo "FATAL: auto-host.h corrupted (DEVSHELL.md)"; exit 9
fi
n=$(grep -c 'insn-codes-union.list' "$D/gcc/Makefile")
echo "gcc/Makefile recreated; insn-codes-union.list mentions: $n"
[ "$n" -ge 2 ] || { echo "FATAL: the new object did not reach the Makefile"; exit 9; }
