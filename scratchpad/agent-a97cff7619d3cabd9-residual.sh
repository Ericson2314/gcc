#!/bin/sh
# agent-a97cff7619d3cabd9-residual.sh -- the 191 `in_hard_reg_set_p' ICEs that
# SURVIVE the virtual-numbering fix.  1,756 -> 191 is not 1,756 -> 0, and the
# remainder is a DIFFERENT producer, not a smaller amount of the same one.
# usage: agent-a97cff7619d3cabd9-residual.sh <builddir> <testfile>
set -u
D=${1:?build dir}; T=${2:?test file, relative to gcc/testsuite}
case "$D" in */b-a97cff7619d3cabd9*) ;; *) echo "FATAL: not this worktree's build dir"; exit 9 ;; esac
SRC=$(cat "$D/MY-SRC"); V=$(cat "$SRC/gcc/BASE-VER")
CFG="$D/lib/gcc/$V/x86_64-pc-linux-gnu/specs-config"
[ -s "$CFG" ] || { echo "FATAL: no $CFG"; exit 9; }
IN="$SRC/gcc/testsuite/$T"
[ -s "$IN" ] || { echo "FATAL: no $IN"; exit 9; }
O="$D/residual"; mkdir -p "$O"
n=$(basename "$T")
( cd "$D/gcc" && ./cc1 -quiet -nostdinc ${MT_CFLAGS:--O2} -ftarget-config="$CFG" "$IN" -o "$O/$n.s" ) \
  > "$O/$n.out" 2> "$O/$n.err"
echo "$T: rc=$?"
sed -n 1,25p "$O/$n.err"
