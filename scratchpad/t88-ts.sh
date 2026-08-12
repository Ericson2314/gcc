#!/bin/sh
# target-specs/configure, once per target, in my own build dir.  Derived from
# scratchpad/t106-ts.sh with SRC and D repointed; `make target-specs' has not
# existed since b850cb24ecf, so rv-specs.sh is stale (and reported rc=0 while
# failing).  Checks the ARTEFACT, not the exit status.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03
D=${D:-/tmp/b88a64}
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
rc=0
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  nix-shell -I "nixpkgs=$NP" \
    -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
    --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && PATH=/tmp/mt-fakebin:\$PATH $SRC/target-specs/configure \
             --with-target=$t --srcdir=$SRC/target-specs" \
    > /tmp/t88-ts-$t.log 2>&1 || { echo "configure FAILED for $t"; rc=1; }
  for f in "$D/gcc/specs-$t" "$D/gcc/specs-$t-config"; do
    if [ -s "$f" ]; then
      echo "ok  $f ($(wc -l < "$f") lines)"
    else
      echo "MISSING/EMPTY $f"; rc=1
    fi
  done
done
echo "t88-ts rc=$rc"
exit $rc
