#!/bin/sh
# #157 -- rebuild the three expand-side objects with -g and relink cc1, so the
# `in as_a, at machmode.h:416' wall has symbols.
#
# The tree's CXXFLAGS are -g0 (t157-conf.sh), so the backtrace symbolises to
# `.cold' / `.part.0' clones and gdb has no locals at all.  PRINCIPLES 4 rule
# 5 -- state your instrument's blind spots -- and this removes one rather than
# reasoning through it.  ONLY these objects change; everything else in the
# link is the measured build.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-af23dd9b01f75c197*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
G=$D/gcc
rm -f "$G/expr.o" "$G/expmed.o" "$G/optabs.o"
sh "$S/eb-shell.sh" "cd $G && make CXXFLAGS='-O2 -g -Wno-error=format-security' expr.o expmed.o optabs.o && make cc1" \
  > "$D/dbg.out" 2> "$D/dbg.err"
echo "rc=$?"
tail -3 "$D/dbg.err"
ls -la "$G/cc1"
