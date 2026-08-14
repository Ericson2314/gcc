#!/bin/sh
# #121 -- configure a build dir for the SELFTEST work, in THIS worktree.
#
# SRC is derived from $0 (this script's own tree) per PRINCIPLES section 4: a
# guard that builds somebody else's tree reports a clean green against a
# compiler that is not the one under test.  The build dir is named after the
# WORKTREE, not the task number: /tmp/b<task> collides by construction because
# task numbers are handed out in neighbouring blocks (PRINCIPLES section 5).
#
# THREE bases, not the habitual two.  The failure under investigation is
# `CImode', which aarch64 has and i386 does not, so the pair cannot distinguish
# "the union leaks a mode into a base that lacks it" from "this mode is broken
# everywhere".  riscv is the third: it is in the 8-clean set, and like i386 it
# has NO CImode, so it is an independent second witness for the absent side.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b-abeb4d62}
WANT=${WANT_ANCHOR:-47}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
echo "srcdir $SRC anchor=$n (expected $WANT) OK"

T=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,riscv64-unknown-linux-gnu

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$T \
  --enable-backends=$T \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
