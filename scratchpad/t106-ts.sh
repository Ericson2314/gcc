#!/bin/sh
# Task #106: run target-specs' OWN configure, once per target, in /tmp/b106/gcc.
#
# `make target-specs' no longer exists -- b850cb24ecf took target-specs out of
# gcc's build, so scratchpad/rv-specs.sh is stale and fails with
# `No rule to make target target-specs'.  This is the replacement.
#
# The fake cross as/ld in /tmp/mt-fakebin are required for aarch64: without
# them the probes answer "no tool" and the config file is quietly pessimistic
# (DEVSHELL.md).
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7faca7bbb57cc84d
D=${D:-/tmp/b106}
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
rc=0
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  nix-shell -I "nixpkgs=$NP" \
    -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
    --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && PATH=/tmp/mt-fakebin:\$PATH $SRC/target-specs/configure \
             --with-target=$t --srcdir=$SRC/target-specs" \
    > /tmp/t106-ts-$t.log 2>&1 || { echo "configure FAILED for $t"; rc=1; }
  # Check the ARTEFACT, not the exit status: a generator can fail and exit 0.
  for f in "$D/gcc/specs-$t" "$D/gcc/specs-$t-config"; do
    if [ -s "$f" ]; then
      echo "ok  $f ($(wc -l < "$f") lines)"
    else
      echo "MISSING/EMPTY $f"; rc=1
    fi
  done
done
echo "t106-ts rc=$rc"
exit $rc
