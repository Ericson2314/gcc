#!/bin/sh
set -e
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-af7e06a12bc211827
mkdir -p /tmp/b-77t
cd /tmp/b-77t
"$SRC/configure" --disable-werror \
  --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto
