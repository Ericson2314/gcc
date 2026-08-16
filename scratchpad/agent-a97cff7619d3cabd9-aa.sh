#!/bin/sh
# agent-a97cff7619d3cabd9-aa.sh -- compile ONE aarch64 test with two build
# dirs' compilers and show what each says.  For the 776 named
# `gcc.target/aarch64' regressions the virtual-numbering fix produced.
# usage: A=<basedir> B=<fixdir> agent-a97cff7619d3cabd9-aa.sh <testfile> [flags]
set -u
A=${A:?base build dir}; B=${B:?fix build dir}
T=${1:?test file relative to gcc/testsuite}
F=${2:--O0 -g}
for D in "$A" "$B"; do
  SRC=$(cat "$D/MY-SRC"); V=$(cat "$SRC/gcc/BASE-VER")
  CFG="$D/lib/gcc/$V/aarch64-unknown-linux-gnu/specs-config"
  IN="$SRC/gcc/testsuite/$T"
  [ -s "$IN" ] || { echo "FATAL: no $IN"; exit 9; }
  O="$D/aa-probe"; mkdir -p "$O"; n=$(basename "$T")
  ( cd "$D/gcc" && ./xgcc -B"$D/gcc/" -B"$D/asdir-aarch64-unknown-linux-gnu/" \
      -ftarget-config="$CFG" -S $F -I"$SRC/gcc/testsuite/gcc.target/aarch64" \
      "$IN" -o "$O/$n.s" ) > "$O/$n.out" 2> "$O/$n.err"
  echo "== $D rc=$?"
  sed -n 1,8p "$O/$n.err"
done
