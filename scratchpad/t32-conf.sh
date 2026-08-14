#!/bin/sh
# t32-conf.sh -- configure a 48-back-end build dir from an IMMUTABLE SNAPSHOT.
#
# Derived from t150-conf.sh.  Two things it does NOT inherit:
#   - SRC is taken from $2, not from $0's location, because $0 lives in the
#     LIVE worktree while the tree under test must be a snapshot nobody can
#     write (PRINCIPLES section 4, "NEVER BUILD FROM THE LIVE WORKING TREE").
#   - It asserts `git diff --quiet' in the snapshot as well as the anchor, so
#     a torn read cannot masquerade as a real defect.
#
# WANT_ANCHOR stays EXACT at 48.  The number is not the invariant, the
# exactness is.
#
# usage: t32-conf.sh <builddir> <snapshot-srcdir> <triple-list-file>
set -e
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
LISTF=${3:?file of triples}
S=$(cd "$(dirname "$0")" && pwd)

WANT=${WANT_ANCHOR:-48}
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet ) || { echo "FATAL: $SRC is not clean"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }

# PRINCIPLES section 5: /tmp/b<task number> IS NOT YOUR OWN.
case "$D" in
  */b-a568476*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

LIST=$(grep -v '^#' "$LISTF" | grep . | tr '\n' ',' | sed 's/,$//')
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }
NT=$(echo "$LIST" | tr ',' '\n' | grep -c .)
echo "srcdir $SRC anchor=$n clean OK; $NT triples"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-targets=$LIST \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O2 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
rc=$?
echo "configure rc=$rc"
grep -m1 'running configure' "$D/config.log" || true
tail -3 "$D/conf.err"
exit $rc
