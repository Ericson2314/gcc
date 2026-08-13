#!/bin/sh
# EXTRA_GCC_OBJS task -- configure a build dir in THIS worktree.
#
# SRC is derived from $0 so the script always builds the tree it lives in
# (PRINCIPLES section 4: 485 of 506 scratchpad scripts name someone else's
# worktree).  The build dir is named after the WORKTREE, never a task number.
#
# usage: eg-conf.sh [builddir] [backend-list]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
W=$(basename "$SRC")
D=${1:-/tmp/b-$W}
BE=${2:-x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,avr-elf,msp430-elf,loongarch64-linux-gnu,arc-elf}

WANT=43
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
echo "srcdir $SRC anchor=$n OK; builddir $D; backends $BE"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$BE \
  --enable-backends=$BE \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
