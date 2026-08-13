#!/bin/sh
# #137 build dir: configure THROUGH THE TOP LEVEL (gcc/ needs --enable-backends
# from there) and assert the tree by content anchor before doing anything.
# The anchor is `MULTI_TARGET' in gcc/Makefile.in: 0 on the bare-repo HEAD a
# worktree is created at, 39 on the current branch.  A build dir configured
# from the wrong tree passes every other check there is.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" -ge 39 ] || { echo "FATAL: $SRC anchor=$n, not a current multi-target tree"; exit 9; }
D=${1:?build dir}
rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
