#!/bin/sh
# Run gcc/configure in a fresh dir with a given back-end-list flag.
# $1 = build dir, $2... = the flag(s) under test
set -e
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a6bf09d706bf026f0/gcc
D=$1; shift
rm -rf "$D"; mkdir -p "$D"
cd "$D"
"$SRC/configure" \
  --srcdir="$SRC" \
  --disable-werror \
  "$@" \
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
