#!/bin/sh
# #136 -- configure a two-base (x86_64 + aarch64) build dir from a t136-snap.sh
# snapshot.  Two bases is the right configuration for this task: UNSPECV_BLOCKAGE
# is 1 for i386 and 5 for aarch64, so the defect lives on exactly this pair.
#
# usage: SRC=<snapshot> WANT_ANCHOR=<n> t136-conf.sh <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to a t136-snap.sh snapshot}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
WANT=${WANT_ANCHOR:?set WANT_ANCHOR}

[ -f "$SRC/SNAP-SHA" ] || { echo "FATAL: $SRC is not a snapshot (no SNAP-SHA)"; exit 9; }
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
case "$D" in
  */b-a5cf4*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

TGTS=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu
rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$TGTS \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
echo "$SRC" > "$D/MY-SRC"
cp "$SRC/SNAP-SHA" "$D/SNAP-SHA"
grep -m1 'running configure' "$D/config.log" || true
tail -3 "$D/conf.err"
