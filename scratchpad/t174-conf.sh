#!/bin/sh
# #174 mode-ordinal arithmetic -- configure an N-back-end build dir FROM AN
# IMMUTABLE SNAPSHOT.  Anchor stays EXACT (see PRINCIPLES: the number is not
# the invariant, the exactness is).
#
# THE TOP LEVEL'S FLAG IS `--enable-targets', NOT `--enable-backends'.  They
# are the same list under two names and the split is deliberate: the top level
# instantiates a target TREE per triple and derives gcc/'s --enable-backends
# from it, so it REFUSES --enable-backends by name (configure.ac:134).  A
# harness that passes the gcc/ spelling here dies in the first ten lines with
# "There is deliberately no `all' here", which reads as a bad triple list.
#
# usage: WANT_ANCHOR=<n> t174-conf.sh <snapdir> <builddir> <list-file> <count>
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
  */b-ac0602*) ;;
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
