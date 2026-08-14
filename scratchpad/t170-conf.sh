#!/bin/sh
# #170 -- configure an ELEVEN-back-end build dir FROM AN IMMUTABLE SNAPSHOT.
#
# Derived from t160-conf.sh.  WANT_ANCHOR stays EXACT (PRINCIPLES section 4:
# the number is not the invariant, the exactness is) and is 50 as of the
# eleven-back-end merge.
#
# usage: t170-conf.sh <snapdir> <builddir> [comma-list|file]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=${3:-$S/t170-bases11.txt}
if [ -f "$LIST" ]; then
  # Column 1 -- what --enable-targets is given.  Column 2 is the canonical
  # spelling the build dir uses afterwards; see t170-bases11.txt.
  LIST=$(grep -v '^#' "$LIST" | awk 'NF{print $1}' | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }

WANT=${WANT_ANCHOR:-50}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }

case "$D" in
  */b-a697b5bfd5294f5e8*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" = 11 ] || { echo "FATAL: $nt triples, expected 11"; exit 9; }
echo "srcdir $SNAP anchor=$n OK; $nt triples"

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
