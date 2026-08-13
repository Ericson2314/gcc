#!/bin/sh
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/../gcc" && pwd)
# REFUSE THE WRONG TREE.  This line used to name ANOTHER agent's
# worktree; those trees measure 27-28 `MULTI_TARGET' hits in
# gcc/Makefile.in against this one's 39, so the script configured and
# built a STALE compiler and reported a clean green for it, with no
# diagnostic.  0 hits is the documented bare-repo-HEAD case
# (PRINCIPLES section 5).
grep -q MULTI_TARGET "$SRC/gcc/Makefile.in" || { echo "FATAL: $SRC is not a multi-target tree"; exit 9; }
cd /tmp/b-eb/gcc
"$SRC/configure" \
  --srcdir="$SRC" \
  --disable-werror \
  --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  --enable-languages=c,lto \
  --program-transform-name=s,y,y, \
  --disable-option-checking \
  --disable-year2038 \
  --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu --target=x86_64-pc-linux-gnu \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security  ' \
  LDFLAGS='-static-libstdc++ -static-libgcc ' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security  ' \
  GMPLIBS='-lmpc -lmpfr -lgmp' GMPINC= ISLLIBS= ISLINC=
