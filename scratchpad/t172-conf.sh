#!/bin/sh
# #172 -- configure a THREE-back-end build (aarch64, riscv64, s390x) from an
# IMMUTABLE SNAPSHOT.  Three, not eleven, because this task's arm is a
# both-sided comparison of ONE function's word size across three back ends and
# nothing here needs the other eight; the three are drawn from #170's proven
# eleven so the link-failure risk PRINCIPLES records for ad-hoc 3-base sets
# does not apply.
#
# WANT_ANCHOR is EXACT (PRINCIPLES section 4).  Measured on this tree: 55.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=aarch64-unknown-linux-gnu,riscv64-unknown-linux-gnu,s390x-linux-gnu

WANT=${WANT_ANCHOR:-55}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }

case "$D" in
  */b-a82dcce59b2d6b84e*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SNAP anchor=$n OK"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SNAP/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
grep -m1 'running configure' "$D/config.log" || true
echo "$SNAP" > "$D/MY-SRC"
tail -3 "$D/conf.err"
