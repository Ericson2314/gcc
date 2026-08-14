#!/bin/sh
# Task #160 / #141 Phases 1-2: configure a two-base build from an IMMUTABLE
# SNAPSHOT worktree, per PRINCIPLES section 4.
#
# usage: t160-conf.sh <snapshot-srcdir> <builddir>
#
# Asserts, all exact and all able to fail:
#   * the MULTI_TARGET anchor in the snapshot's gcc/Makefile.in is exactly
#     $WANT_ANCHOR (default 48).  NEVER relax this to `>=': the whole point is
#     that a tree missing a landed change fails HERE rather than reporting a
#     green for a compiler that is not the one under test.
#   * the snapshot has no uncommitted change, so the srcdir cannot move under
#     the build;
#   * the build dir is named for THIS worktree, because /tmp/b<task number>
#     collides by construction (measured live, PRINCIPLES section 5).
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${1:?snapshot srcdir}
D=${2:?build dir}
SRC=$(cd "$SRC" && pwd)
WANT=${WANT_ANCHOR:-48}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is not clean; a build whose srcdir can change measures nothing"; exit 9; }
case "$D" in
  */b-a51d424a65fb6e21d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n clean OK -> $D"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"
