#!/bin/sh
# Task #160 -- the acceptance bars, in MY build dir, from MY snapshot.
#
# Every byte count is quoted with the INPUT PATH beside it: `-S' emits a
# `.file' directive, so a byte count with no input named is evidence about a
# filename (PRINCIPLES 6, the aarch64 369/371/373 case).
# usage: t160-bars.sh <builddir> <snapshot-srcdir>
set -u
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
V=17.0.0
OUT=$D/t160-bars
mkdir -p $OUT
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:-48}" ] \
  || { echo "FATAL: snapshot anchor is not ${WANT_ANCHOR:-48}"; exit 9; }
rc=0
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  c=$D/lib/gcc/$V/$t/specs-config
  [ -s "$c" ] || { echo "FATAL: no specs-config for $t at $c"; exit 9; }
  # BOTH counts, because the recorded bar exists as two numbers.  PRINCIPLES
  # 6 attributes 230-vs-222 to "different configurations"; measured here they
  # are the SAME FILE, md5 for md5 -- `wc -l' counts 230 and `grep -c .' counts
  # 222, the difference being 8 blank lines.  Print both so the next reader
  # cannot pick the wrong one.
  echo "specs-config $t: $(wc -l < "$c") lines (wc -l), $(grep -c . "$c") non-blank  md5 $(md5sum < "$c" | cut -c1-12)"
done
run () { # $1 target  $2 input  $3 tag  ... flags
  t=$1; in=$2; tag=$3; shift 3
  [ -s "$in" ] || { echo "FATAL: input missing or empty: $in"; exit 9; }
  ( cd $D/gcc && ./cc1 -quiet -nostdinc "$@" \
      -ftarget-config="$D/lib/gcc/$V/$t/specs-config" \
      "$in" -o $OUT/$tag.s ) 2> $OUT/$tag.err
  r=$?
  if [ $r != 0 ] || [ ! -s $OUT/$tag.s ]; then
    echo "$tag: FAIL rc=$r"; sed -n 1,8p $OUT/$tag.err; rc=1; return 1
  fi
  echo "$tag [$t] in=$in : $(wc -c < $OUT/$tag.s) bytes  md5 $(md5sum < $OUT/$tag.s | cut -c1-12)"
}
run x86_64-pc-linux-gnu "$SRC/scratchpad/big.c" x86-big -O2
exit $rc
