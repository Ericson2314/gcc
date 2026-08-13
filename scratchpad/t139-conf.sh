#!/bin/sh
# #139 -- configure a build dir for the THROUGHPUT measurement.
#
# Differs from t137-conf.sh in exactly two ways, both deliberate:
#
#  * CXXFLAGS is -O2, not -O1.  The question being asked is what an indirect
#    call costs in a compiler anyone would ship, and at -O1 the host compiler
#    does not inline the things whose non-inlining is the entire hypothesis.
#    An -O1 measurement would overstate the baseline and understate nothing --
#    it is simply not the compiler under discussion.
#  * The source tree is an ARGUMENT, because two different trees (branch HEAD
#    and a pre-conversion commit) must be built with byte-identical flags for
#    the comparison to mean anything.  t137-conf.sh derives SRC from $0, which
#    is right for a guard and wrong for an A/B.
#
# The anchor check is kept and generalised: the caller states the anchor it
# expects, because the pre-conversion tree legitimately has FEWER MULTI_TARGET
# hits than HEAD (37 vs 39) and a >=39 test would refuse the very baseline
# this task exists to build.  An exact expected value fails both ways.
#
# usage: t139-conf.sh <srcdir> <builddir> <expected-anchor>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "${1:?srcdir}" && pwd)
D=${2:?build dir}
WANT=${3:?expected MULTI_TARGET anchor in gcc/Makefile.in}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
echo "srcdir $SRC anchor=$n (expected $WANT) OK"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
