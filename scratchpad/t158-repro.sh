#!/bin/sh
# #158 -- REPRODUCE the silent discard, and give the fix a negative control.
#
# Pass BOTH spellings, disagreeing: --enable-targets names two triples,
# --enable-backends says `all'.  Then run ONLY `make configure-gcc', which is
# the step that runs gcc/configure, and read gcc/config.log -- the build's own
# testimony about the argv it was handed.
#
# usage: t158-repro.sh <snapdir> <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SNAP=${1:?snap dir}
D=${2:?build dir}
case "$D" in
  */b-afc48f6a11df7294e*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
WANT=${WANT_ANCHOR:-48}
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SNAP anchor=$n, expected exactly $WANT"; exit 9; }

rm -rf "$D"; mkdir -p "$D"
set +e
sh "$S/eb-shell.sh" "cd $D && $SNAP/configure \
  --disable-werror \
  --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
  --enable-backends=all \
  --disable-bootstrap --disable-nls \
  --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
  CC=gcc CFLAGS='-O2 -g0' CXX=g++ CXXFLAGS='-O2 -g0' \
  --enable-languages=c" > "$D/conf.out" 2> "$D/conf.err"
rc=$?
set -e
echo "top-level configure rc=$rc"
echo "--- top-level configure stderr (last 12) ---"
tail -12 "$D/conf.err"

if [ "$rc" != 0 ]; then
  echo "REFUSED at the top level -- this is the FIXED behaviour."
  exit 0
fi

echo "ACCEPTED at the top level -- now what does gcc/ actually get?"
sh "$S/eb-shell.sh" "cd $D && make configure-gcc" > "$D/cg.out" 2> "$D/cg.err" || true
[ -f "$D/gcc/config.log" ] || { echo "FATAL: no gcc/config.log; configure-gcc did not run"; exit 9; }
echo "--- every --enable-backends= in gcc/config.log, in argv order ---"
tr ' ' '\n' < "$D/gcc/config.log" | grep '^--enable-backends=' || \
  { echo "FATAL: gcc/config.log names no --enable-backends at all"; exit 9; }
echo "--- what gcc/ concluded ---"
grep -m2 'backends\|back end' "$D/gcc/config.log" | head -5 || true
