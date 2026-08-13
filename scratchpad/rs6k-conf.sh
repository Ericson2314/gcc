#!/bin/sh
# rs6000 grind -- configure i386 + aarch64 + rs6000 in THIS worktree.
# Build dir is named for the WORKTREE, never for a task number (PRINCIPLES 5).
# The top level's --enable-targets -> --enable-backends mapping is broken at
# HEAD, so --enable-backends is passed explicitly; that is a documented
# workaround, not a fix, and is owned by another agent.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b-a5fb19dec8368eaf6}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = 43 ] || { echo "FATAL: $SRC anchor=$n, expected 43"; exit 9; }
echo "srcdir $SRC anchor=$n OK"

TGTS=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,powerpc64le-unknown-linux-gnu

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$TGTS \
  --enable-backends=$TGTS \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
