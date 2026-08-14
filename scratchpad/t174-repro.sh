#!/bin/sh
CC1=${CC1:-/tmp/b-a78a/gcc/cc1}
A=${A:-/tmp/b-a78a/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config}
SRCT=${SRCT:-/tmp/snap-ab0e/gcc/testsuite}
for t in gcc.dg/20000111-1.c gcc.dg/20000906-1.c gcc.dg/20001116-1.c; do
  for o in "" -O0 -O1 -O2 -O3 -Os; do
    out=$($CC1 -quiet -nostdinc $o -ftarget-config=$A $SRCT/$t -o /tmp/ab0e-out.s 2>&1)
    ice=$(echo "$out" | grep -m1 'internal compiler error')
    echo "$t [$o] ${ice:-ok}"
  done
done
