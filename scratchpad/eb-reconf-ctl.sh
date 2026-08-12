#!/bin/sh
# Identical to eb-reconf.sh except it uses the OLD flag spelling, so that the
# ONLY difference between /tmp/b-eb and /tmp/b-eb-ctl is the rename itself.
set -e
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a6bf09d706bf026f0/gcc
cd /tmp/b-eb-ctl/gcc
"$SRC/configure" \
  --srcdir="$SRC" \
  --disable-werror \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
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
