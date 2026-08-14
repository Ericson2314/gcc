#!/bin/sh
# The CONTROL for the rs6000 grind: the SAME tree, the SAME flags, but the
# established i386 + aarch64 pair only.  Without it, an x86_64 failure in the
# three-back-end dir cannot be attributed -- "my change broke it" and "the
# third back end broke it" look identical.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b-aa95b761351d960a4-pair}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:-47}" ] || { echo "FATAL: $SRC anchor=$n, expected exactly ${WANT_ANCHOR:-47}"; exit 9; }

TGTS=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu

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
