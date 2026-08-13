#!/bin/sh
# Configure a build dir for the `target_*' struct-layout sweep (worktree
# agent-ad827eb24f334c52d).  Build dirs are named for the WORKTREE, never for
# a task number -- task numbers collide by construction (PRINCIPLES 5).
#
# usage: mtsw-conf.sh <builddir> pair|triple
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
WHICH=${2:?pair|triple}

WANT=${WANT_ANCHOR:-47}
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }

case "$D" in
  */b-ad827eb24f334c52d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

case "$WHICH" in
  pair)   TGTS=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu ;;
  triple) TGTS=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,powerpc64le-unknown-linux-gnu ;;
  # INSTRUMENT ONLY, not an acceptance configuration.  xtensa is one of the
  # back ends whose MAX_BITS_PER_WORD is 32, so this is the smallest build in
  # which the `target_expmed'/`target_lower_subreg' divergence can be MEASURED
  # rather than argued from the headers.  It is not expected to build to
  # completion (xtensa is not among the back ends that currently do); what it
  # is used for is its generated per-base headers.
  xtensa) TGTS=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,xtensa-elf ;;
  *) echo "FATAL: want pair|triple|xtensa"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n OK; list=$TGTS"

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
