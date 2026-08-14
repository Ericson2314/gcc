#!/bin/sh
# Tasks #143 / #154 / #49 -- configure a build dir from an IMMUTABLE SNAPSHOT.
#
# usage: t143-conf.sh <snapshot-srcdir> <builddir> <all | comma-separated triples>
#
# Asserts, all exact and all able to fail (PRINCIPLES section 4/5):
#   * the snapshot's gcc/Makefile.in MULTI_TARGET anchor is exactly $WANT_ANCHOR
#     (48 today).  EXACT, never `>=': a tree missing a landed change must fail
#     here rather than report a green for a compiler that is not this one.
#   * the snapshot has no uncommitted change, so the srcdir cannot move under
#     the build.  NEVER BUILD FROM THE LIVE WORKING TREE.
#   * the build dir is named for THIS worktree; /tmp/b<task number> collides by
#     construction and has been measured doing so.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${1:?snapshot srcdir}
D=${2:?build dir}
LIST=${3:?comma-separated triple list, or a file with one triple per line}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | grep . | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }
SRC=$(cd "$SRC" && pwd)
WANT=${WANT_ANCHOR:-48}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is not clean; a build whose srcdir can change measures nothing"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }
case "$D" in
  */b-ad1798a2b26398cc6*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n clean OK -> $D  list=$LIST"

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
# The build's own testimony about which tree configure ran from -- independent
# of this script by construction (PRINCIPLES section 4).
grep -m1 'running configure' "$D/config.log" || true
tail -3 "$D/conf.err"
exit $rc
