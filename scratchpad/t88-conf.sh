#!/bin/sh
# Task #88/#104: configure a build dir from THIS worktree.
#   t88-conf.sh <builddir> <backend-list>
set -e
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03
D=$1; shift
BE=$1; shift
mkdir -p "$D"
cd "$D"
"$SRC/configure" --disable-werror \
  --enable-backends="$BE" \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto
