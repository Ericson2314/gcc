#!/bin/sh
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7b00eeb03e7b153b
I=/home/jcericson/src/gnu/gcc/inst-b-a7b00eeb03e7b153b
cd /tmp/a7b00-lg-aarch64
"$I/bin/aarch64-unknown-linux-gnu-gcc" -O2 -DIN_GCC -fPIC -DIN_LIBGCC2 \
  -fbuilding-libgcc -I. -I"$I/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/include" \
  -I"$W/libgcc" -I"$W/libgcc/../gcc" -I"$W/libgcc/../include" \
  -g -S "$W/libgcc/config/aarch64/heap-trampoline.c" -o ht.s
sed -n '694,700p' ht.s
echo "--- grep for the bad line:"
grep -n 'd$\|[0-9]d\b' ht.s | head -5
