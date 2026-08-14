#!/bin/sh
# #155 -- configure an N-back-end build dir FROM AN IMMUTABLE SNAPSHOT.
#
# usage: t155-conf.sh <snapdir> <builddir> [comma-list|file]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=${3:-$S/all-backends.txt}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | grep . | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }

# PRINCIPLES section 4: the anchor is EXACT, never >=.  48 as of the
# add_clobbers selector (#150).
WANT=${WANT_ANCHOR:-48}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }

# NEVER BUILD FROM THE LIVE WORKING TREE -- a torn read names real symbols.
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }

# /tmp/b<task number> IS NOT YOUR OWN: name the build dir after the WORKTREE.
case "$D" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" -ge 2 ] || { echo "FATAL: only $nt triples"; exit 9; }
echo "srcdir $SNAP anchor=$n OK, clean; $nt triples"

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
echo "$SNAP" > "$D/T155-SRCDIR"
echo "$nt" > "$D/T155-NTRIPLES"
tail -3 "$D/conf.err"
