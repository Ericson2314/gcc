#!/bin/sh
# gengtype / machine_function task -- configure a build dir with an arbitrary
# target list.
#
# Derived from mta7-conf.sh + t139-conf.sh.  Guards kept deliberately:
#
#  * SRC derived from $0 (THIS script's tree), never hardcoded -- PRINCIPLES 4,
#    "a guard script can build somebody else's tree and report a clean green".
#  * The MULTI_TARGET anchor in gcc/Makefile.in is asserted EXACTLY (45), so a
#    tree missing landed changes fails here instead of producing a green for a
#    compiler that is not this one.
#  * The build dir must be named for THIS WORKTREE, never a task number:
#    /tmp/b<task number> collides by construction (measured live: another agent
#    reconfigured the same path mid-task).
#
# usage: gt-conf.sh <builddir> <comma-separated-triples | file-of-triples>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
LIST=${2:?comma-separated triple list, or a file with one triple per line}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | grep . | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }
WANT=${WANT_ANCHOR:-45}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }
case "$D" in
  */b-a2c4f72addc68d136*) ;;
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
  --enable-languages=c,lto"
