#!/bin/sh
# Task #88/#104: configure a build dir from THIS worktree.
#   t88-conf.sh <builddir> <backend-list>
set -e
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
# REFUSE THE WRONG TREE.  This line used to name ANOTHER agent's
# worktree; those trees measure 27-28 `MULTI_TARGET' hits in
# gcc/Makefile.in against this one's 39, so the script configured and
# built a STALE compiler and reported a clean green for it, with no
# diagnostic.  0 hits is the documented bare-repo-HEAD case
# (PRINCIPLES section 5).
grep -q MULTI_TARGET "$SRC/gcc/Makefile.in" || { echo "FATAL: $SRC is not a multi-target tree"; exit 9; }
D=$1; shift
BE=$1; shift
mkdir -p "$D"
cd "$D"
"$SRC/configure" --disable-werror \
  --enable-targets="$BE" \
  --enable-backends="$BE" \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto
