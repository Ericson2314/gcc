#!/bin/sh
# #176 -- the x86_64 -O2 codegen bar on scratchpad/big.c, in MY build dir,
# from MY snapshot.  Adapted from t160-bars.sh.
#
# The INPUT PATH is printed beside every byte count (PRINCIPLES 6: `-S' emits
# a `.file' directive, so a byte count with no input named is evidence about a
# filename).  Recorded two-base bar: 12369 bytes / md5 378fc33c1e70.
#
# usage: t164-bars.sh <builddir> <snapshot-srcdir> [tag]
set -u
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
TAG=${3:-bars}
V=17.0.0
OUT=$D/$TAG
mkdir -p "$OUT"
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] \
  || { echo "FATAL: snapshot anchor mismatch"; exit 9; }
t=x86_64-pc-linux-gnu
c=$D/lib/gcc/$V/$t/specs-config
[ -s "$c" ] || { echo "FATAL: no specs-config for $t at $c"; exit 9; }
echo "specs-config $t: wc -l $(wc -l < "$c")  grep -c . $(grep -c . "$c")  md5 $(md5sum < "$c" | cut -c1-12)"
IN=$SRC/scratchpad/big.c
[ -s "$IN" ] || { echo "FATAL: input missing: $IN"; exit 9; }
( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" \
    "$IN" -o "$OUT/x86-big.s" ) > "$OUT/x86-big.out" 2> "$OUT/x86-big.err"
r=$?
if [ $r != 0 ] || [ ! -s "$OUT/x86-big.s" ]; then
  echo "x86-big [$t] in=$IN : FAIL rc=$r"
  sed -n 1,12p "$OUT/x86-big.err"
  exit 1
fi
echo "x86-big [$t] in=$IN : $(wc -c < "$OUT/x86-big.s") bytes  md5 $(md5sum < "$OUT/x86-big.s" | cut -c1-12)"

# THE aarch64 ARM, which the #164 script did not have.  Recorded two-base bar
# at b2b5b42b128: 12196 bytes / md5 9edf6aa6616c.  Quoted WITH its input path,
# for the reason in the header comment.
t=aarch64-unknown-linux-gnu
c=$D/lib/gcc/$V/$t/specs-config
[ -s "$c" ] || { echo "FATAL: no specs-config for $t at $c"; exit 9; }
echo "specs-config $t: wc -l $(wc -l < "$c")  grep -c . $(grep -c . "$c")  md5 $(md5sum < "$c" | cut -c1-12)"
( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" \
    "$IN" -o "$OUT/a64-big.s" ) > "$OUT/a64-big.out" 2> "$OUT/a64-big.err"
r=$?
if [ $r != 0 ] || [ ! -s "$OUT/a64-big.s" ]; then
  echo "a64-big [$t] in=$IN : FAIL rc=$r"
  sed -n 1,12p "$OUT/a64-big.err"
  exit 1
fi
echo "a64-big [$t] in=$IN : $(wc -c < "$OUT/a64-big.s") bytes  md5 $(md5sum < "$OUT/a64-big.s" | cut -c1-12)"
