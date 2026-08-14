#!/bin/sh
# #150 / #128-emit -- configure a build dir with a deliberately chosen base set.
#
# Derived from mtN-conf.sh, with WANT_ANCHOR=47 per PRINCIPLES section 4: the
# pre-existing *-conf.sh scripts assert 45 exactly and now refuse a CORRECT
# tree.  The assert stays EXACT -- the number is not the invariant, the
# exactness is.
#
# usage: t150-conf.sh <builddir> <comma-separated-triples | file-of-triples>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
LIST=${2:?comma-separated triple list, or a file with one triple per line}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | grep . | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }
WANT=${WANT_ANCHOR:-47}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }
# PRINCIPLES section 5: /tmp/b<task number> IS NOT YOUR OWN.  Name the build
# dir after the worktree, and refuse anything else.
case "$D" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n OK; list=$LIST"

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
# The build's own testimony about which tree it was configured from
# (PRINCIPLES section 4): independent of this script by construction.
grep -m1 'running configure' "$D/config.log" || true
tail -3 "$D/conf.err"
