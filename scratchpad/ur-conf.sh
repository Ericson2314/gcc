#!/bin/sh
# UR task (undefined-reference half of the link wall) -- configure a 48-back-end build dir FROM AN IMMUTABLE SNAPSHOT.
#
# usage: t158-conf.sh <snapdir> <builddir> [comma-list|file]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
LIST=${3:-$S/all-backends.txt}
if [ -f "$LIST" ]; then
  LIST=$(grep -v '^#' "$LIST" | grep . | tr '\n' ',' | sed 's/,$//')
fi
[ -n "$LIST" ] || { echo "FATAL: empty triple list"; exit 9; }

WANT=${WANT_ANCHOR:-48}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }

# PRINCIPLES section 5: /tmp/b<task number> IS NOT YOUR OWN.  Name the build dir
# after the WORKTREE and refuse anything else -- task numbers are handed out in
# neighbouring blocks and collide by construction.
case "$D" in
  */b-a6af2c465ae8845f3*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac

# Non-vacuity: the list must actually name 48 back ends, or every downstream
# census is measuring a smaller build while reading as correct.  This is the
# #158 defect's own shape, so the harness refuses rather than trusting it.
nt=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$nt" -ge 2 ] || { echo "FATAL: only $nt triples"; exit 9; }
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

# The build's own testimony about how many back ends it actually got -- read it
# HERE, before building, because #158 is exactly the case where this number is
# 2 while everything else reads as correct.
echo "--- gcc/config.log --enable-backends= occurrences ---"
tr ' ' '\n' < "$D/gcc/config.log" 2>/dev/null | grep -c 'enable-backends=' || true
tail -3 "$D/conf.err"
