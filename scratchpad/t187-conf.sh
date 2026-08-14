#!/bin/sh
# #187 -- configure a build dir with a chosen base set, from an IMMUTABLE
# SNAPSHOT.  Derived from t176-conf.sh; only the build-dir name assertion
# differs, and that assertion is the whole reason for the copy: it must name
# THIS worktree, so a script inherited by the next agent refuses rather than
# measuring somebody else's tree (PRINCIPLES 5, and the FOREIGN-SRC audit).
#
# usage: SRC=<snapshot> WANT_ANCHOR=<n> t187-conf.sh <builddir> <triples,...>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to an immutable snapshot worktree}
SRC=$(cd "$SRC" && pwd)
D=${1:?build dir}
LIST=${2:?comma-separated triple list}
WANT=${WANT_ANCHOR:?set WANT_ANCHOR}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
[ -f "$SRC/SNAP-SHA" ] || { echo "FATAL: $SRC is not a snapshot (no SNAP-SHA)"; exit 9; }
[ ! -w "$SRC/gcc/Makefile.in" ] || { echo "FATAL: $SRC is writable"; exit 9; }
grep -q 'gcc_backends_arg' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure has no gcc_backends_arg mapping"; exit 9; }
case "$D" in
  */b-agent-a85d505af66ec2223*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
echo "srcdir $SRC anchor=$n OK; bases=$(echo "$LIST" | tr ',' '\n' | wc -l)"

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
grep -m1 'running configure' "$D/config.log" || true
echo "$SRC" > "$D/MY-SRC"
tail -3 "$D/conf.err"
