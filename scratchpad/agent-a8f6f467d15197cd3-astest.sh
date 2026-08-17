#!/bin/sh
# agent-a8f6f467d15197cd3-astest.sh -- assert every cross `as' in a tools dir
# RUNS, not that a path exists.
#
# INSTRUMENTS.md's `OK' verdict is defined as "`<prefix>-as --version'
# EXECUTED", and the reason is recorded there: a dangling symlink or a
# wrong-arch binary is exactly the shape that falls back to the host `as'
# three layers away, which is worth ~10,000 wrong results per target.  A tools
# directory inherited from an earlier worktree is the case that needs this --
# the binaries are nix store paths and a store GC leaves the symlinks behind.
set -u
T=${1:?tools dir}
n=0; ok=0; dead=0
for f in "$T"/*-as; do
  [ -e "$f" ] || continue
  n=$((n + 1))
  if "$f" --version > /dev/null 2>&1; then ok=$((ok + 1)); else
    dead=$((dead + 1)); echo "DEAD: $f"; fi
done
echo "tools dir $T: as-binaries=$n executed=$ok dead=$dead"
# A tools dir with ZERO assemblers is the null result this refuses to pass:
# "every assembler works" and "there are no assemblers" are the same clean run.
[ "$n" -gt 0 ] || { echo "REFUSE: no *-as at all in $T"; exit 9; }
[ "$dead" = 0 ] || exit 9
