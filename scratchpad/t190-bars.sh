#!/bin/sh
# #190 -- the x86_64 CONTROL bar only.  Derived from t160-bars.sh, with the
# aarch64 arm dropped: t190-specs.sh probes x86_64 alone (the control this
# task needs is "x86_64 unchanged in all seven columns"), and t160-bars.sh's
# FATAL on a missing aarch64 specs-config is correct behaviour for t160 and
# simply not this task's question.  Every byte count is quoted WITH ITS INPUT
# PATH: `-S' emits a `.file' directive, so a byte count with no input named is
# evidence about a filename (PRINCIPLES 6).
set -u
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
V=17.0.0
OUT=$D/t190-bars
mkdir -p $OUT
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] \
  || { echo "FATAL: snapshot anchor mismatch"; exit 9; }
t=x86_64-pc-linux-gnu
c=$D/lib/gcc/$V/$t/specs-config
[ -s "$c" ] || { echo "FATAL: no specs-config at $c"; exit 9; }
echo "specs-config $t: $(wc -l < "$c") lines (wc -l), $(grep -c . "$c") non-blank  md5 $(md5sum < "$c" | cut -c1-12)"
in=$SRC/scratchpad/big.c
[ -s "$in" ] || { echo "FATAL: input missing: $in"; exit 9; }
( cd $D/gcc && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" "$in" -o $OUT/x86-big.s ) 2> $OUT/x86-big.err
r=$?
if [ $r != 0 ] || [ ! -s $OUT/x86-big.s ]; then
  echo "x86-big: FAIL rc=$r"; sed -n 1,8p $OUT/x86-big.err; exit 1
fi
echo "x86-big [$t] in=$in : $(wc -c < $OUT/x86-big.s) bytes  md5 $(md5sum < $OUT/x86-big.s | cut -c1-12)"
