#!/bin/sh
# agent-a97cff7619d3cabd9-ice.sh -- the NAMED REPRODUCER for
# `in_hard_reg_set_p, at regs.h:312' on x86_64, plus a POSITIVE CONTROL.
#
# Two arms, because "the ICE is gone" and "the compiler still compiles this
# file" are different claims and the first is satisfiable by the file failing
# some other way:
#
#   ARM 1  the reproducer must ICE (unfixed) / must NOT ICE (fixed), AND on
#          the fixed tree must produce a NON-EMPTY .s -- an empty or truncated
#          output with rc=0 is the shape this branch calls a false green.
#   ARM 2  a file that has never ICEd (big.c) must compile on BOTH trees.  If
#          arm 2 ever fails, arm 1's green says nothing about this cause.
#
# usage: agent-a97cff7619d3cabd9-ice.sh <builddir> <tag>
set -u
D=${1:?build dir}; TAG=${2:?tag}
case "$D" in */b-a97cff7619d3cabd9*) ;; *) echo "FATAL: not this worktree's build dir"; exit 9 ;; esac
SRC=$(cat "$D/MY-SRC")
V=$(cat "$SRC/gcc/BASE-VER")
CFG="$D/lib/gcc/$V/x86_64-pc-linux-gnu/specs-config"
[ -s "$CFG" ] || { echo "FATAL: no specs-config at $CFG"; exit 9; }
O="$D/ice-$TAG"; rm -rf "$O"; mkdir -p "$O"

run () { # name source
  n=$1; f=$2
  [ -s "$f" ] || { echo "FATAL: missing input $f"; exit 9; }
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$CFG" "$f" \
      -o "$O/$n.s" ) > "$O/$n.out" 2> "$O/$n.err"
  rc=$?
  ice=$(grep -c 'internal compiler error' "$O/$n.err")
  sz=0; [ -f "$O/$n.s" ] && sz=$(wc -c < "$O/$n.s")
  echo "$n: rc=$rc ICE=$ice bytes=$sz"
  grep -m2 -e 'internal compiler error' -e 'at regs.h' "$O/$n.err" | sed 's/^/    /'
}

run reproducer "$SRC/gcc/testsuite/gcc.c-torture/compile/pr118362.c"
run control    "$SRC/scratchpad/big.c"
