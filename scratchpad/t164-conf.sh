#!/bin/sh
# #164 -- configure an N-back-end build dir FROM AN IMMUTABLE SNAPSHOT.
# Derived from t170-conf.sh.  Anchor stays EXACT; 55 as of 80bf400ae06.
# Built with -g (not -g0) because this task needs a gdb backtrace out of cc1.
#
# usage: t164-conf.sh <snapdir> <builddir> <comma-list-or-file> <count>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=${3:?triple list}
NWANT=${4:?expected triple count}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | awk 'NF{print $1}' | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }

WANT=${WANT_ANCHOR:?set WANT_ANCHOR}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }

case "$D" in
  */b-a1c6fa*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" = "$NWANT" ] || { echo "FATAL: $nt triples, expected $NWANT"; exit 9; }
echo "srcdir $SNAP anchor=$n OK; $nt triples: $LIST"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SNAP/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O1 -g -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?"
grep -m1 'running configure' "$D/config.log" || true
echo "$SNAP" > "$D/MY-SRC"
tail -3 "$D/conf.err"
