#!/bin/sh
# #145 -- poly_int residue classification.  Configure a 47-back-end build in
# THIS worktree.  SRC is derived from $0 so the script can never build another
# agent's tree (PRINCIPLES section 4), and the anchor is asserted EXACTLY at
# 47 -- not `>=' -- because the whole point is that a tree missing the landed
# changes fails here rather than reporting a green for a different compiler.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${D:-/tmp/b-a88fe2f04579b6092}
WANT_ANCHOR=${WANT_ANCHOR:-47}

n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT_ANCHOR" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT_ANCHOR"; exit 9; }
echo "srcdir $SRC anchor=$n OK"

rm -rf "$D"; mkdir -p "$D"
sh "$S/eb-shell.sh" "cd $D && $SRC/configure \
  --disable-werror \
  --enable-backends=all \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure done (rc not scored); stderr $(wc -l < "$D/conf.err") lines"
sh "$S/eb-shell.sh" "cd $D && make configure-gcc" > "$D/cg.out" 2> "$D/cg.err"
echo "configure-gcc stderr $(wc -l < "$D/cg.err") lines"
M="$D/gcc/multi-target.manifest"
[ -s "$M" ] || { echo "FATAL: empty/missing $M"; exit 9; }
echo "backends configured: $(grep -c '^base ' "$M" || grep -c '^target ' "$M")"
echo "D=$D"
