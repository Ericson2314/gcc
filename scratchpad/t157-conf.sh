#!/bin/sh
# #157 -- configure a build dir with a chosen base set, from an IMMUTABLE
# SNAPSHOT.  Derived from t150-conf.sh.
#
# Two things this asserts that t150-conf.sh does not:
#   * the srcdir is CLEAN (`git diff --quiet' plus no untracked tracked-ish
#     files), because PRINCIPLES section 4 records a coordinator build from a
#     live tree that reported `multiple definition of add_clobbers' -- a
#     perfect diagnosis of a state existing in no commit.
#   * the anchor, EXACTLY 48.  Never `>='.
#
# usage: SRC=<snapshot> t157-conf.sh <builddir> <comma-separated-triples>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to an immutable snapshot worktree}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
LIST=${2:?comma-separated triple list}
WANT=${WANT_ANCHOR:-48}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is not clean; a build whose sources can change under it measures nothing"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }
case "$D" in
  */b-af23dd9b01f75c197*) ;;
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
# The build's own testimony about which tree it was configured from.
grep -m1 'running configure' "$D/config.log" || true
echo "$SRC" > "$D/MY-SRC"
tail -3 "$D/conf.err"
