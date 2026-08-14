#!/bin/sh
# #169 -- the ordinary two-base build, for the cc1 that both-sides #162.
# Derived from t165-conf.sh; WANT_ANCHOR is 50 and the build-dir assertion
# names THIS worktree (PRINCIPLES 5: /tmp/b<task number> is not your own).
#
# usage: SRC=<snapshot> t169-2base-conf.sh <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to an immutable snapshot worktree}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
LIST=${2:-x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu}
WANT=${WANT_ANCHOR:-50}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is not clean"; exit 9; }
case "$D" in
  */b2-ab60dd*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n clean OK; list=$LIST"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
echo "$SRC" > "$D/MY-SRC"
grep -m1 'running configure' "$D/config.log" || true
tail -3 "$D/conf.err"
