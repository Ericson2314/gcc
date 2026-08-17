#!/bin/sh
# Is the heap-trampoline.o assembler failure MINE (the installed header set) or
# the compiler's?  Same file, same flags, TWO include roots:
#   A: the installed per-target directory this task adds
#   B: the gcc BUILD tree's own aarch64-inc + build dir, i.e. the headers an
#      in-tree build would have used
# If both fail identically the headers are not the cause.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7b00eeb03e7b153b
I=/home/jcericson/src/gnu/gcc/inst-b-a7b00eeb03e7b153b
B=/home/jcericson/src/gnu/gcc/b-a7b00eeb03e7b153b
CC="$I/bin/aarch64-unknown-linux-gnu-gcc"
SRC="$W/libgcc/config/aarch64/heap-trampoline.c"
COMMON="-O2 -DIN_GCC -W -Wall -fPIC -g -DIN_LIBGCC2 -fbuilding-libgcc -fno-stack-protector -fexceptions -fvisibility=hidden -DHIDE_EXPORTS -B/home/jcericson/src/gnu/gcc/t246-a7b00/aarch64/"
LATE="-I$W/libgcc -I$W/libgcc/../gcc -I$W/libgcc/../include"
cd /tmp
for arm in A B; do
  case $arm in
    A) INC="-I$I/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/include" ;;
    B) INC="-I$B/gcc/aarch64-inc -I$B/gcc" ;;
  esac
  echo "=== arm $arm: $INC"
  $CC $COMMON $INC $LATE -save-temps=obj -c "$SRC" -o /tmp/ht-$arm.o 2>&1 | head -6
  echo "  rc=$? object=$([ -f /tmp/ht-$arm.o ] && echo yes || echo NO)"
  rm -f /tmp/ht-$arm.o
done
