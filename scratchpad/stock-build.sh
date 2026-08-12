#!/usr/bin/env bash
# Task #61: build a genuine STOCK GCC at the branch's merge-base with upstream
# master (c31b7a09eea), configured for x86_64 only, so that the multi-target
# cc1 can for the first time be compared against unmodified GCC.
set -o pipefail
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
B=/tmp/b-stock
S=/tmp/stock-src
SYSHDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

# The reference must be upstream, at the merge-base, in a tree that has none of
# this branch in it -- so check it out rather than assuming one is lying around,
# and refuse if it is not clean.
HERE=$(cd "$(dirname "$0")" && pwd)
MB=$(cd "$HERE/.." && git merge-base HEAD upstream/master) || exit 9
[ -n "$MB" ] || { echo "FATAL: no merge-base with upstream/master"; exit 9; }
if [ ! -d "$S" ]; then
  (cd "$HERE/.." && git worktree add --detach "$S" "$MB") || exit 9
fi
[ "$(cd "$S" && git rev-parse HEAD)" = "$MB" ] \
  || { echo "FATAL: $S is not at the merge-base $MB"; exit 9; }
[ -z "$(cd "$S" && git status --porcelain)" ] \
  || { echo "FATAL: $S is not clean; it would not be a stock reference"; exit 9; }
echo "stock reference tree: $S at $MB"

mkdir -p "$B" || exit 9
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run '
  set -e
  export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
  for t in gcc g++ make flex bison perl; do
    command -v $t >/dev/null || { echo "FATAL missing $t"; exit 9; }
  done
  cd '"$B"'
  if [ ! -f config.status ]; then
    '"$S"'/configure --disable-werror --enable-languages=c \
      --enable-targets=x86_64-pc-linux-gnu --disable-bootstrap --disable-nls --disable-multilib \
      --with-native-system-header-dir='"$SYSHDR"'
  fi
  if grep -n "define rlim_t" gcc/auto-host.h; then echo "FATAL auto-host.h corrupted"; exit 9; fi
  make -j32 all-gcc
' > /tmp/b-stock.log 2>/tmp/b-stock.err
echo "exit=$?"
ls -la "$B/gcc/cc1" 2>&1
