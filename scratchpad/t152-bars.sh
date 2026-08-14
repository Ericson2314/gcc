#!/bin/sh
# Task #152 -- the codegen bars, in MY build dir, from MY snapshot.
# Input paths are quoted with every byte count: `-S' emits a `.file'
# directive, so a byte count is evidence about a FILENAME unless the input is
# named beside it (PRINCIPLES 6).
set -u
D=/tmp/b-a2ee9df2670e0c150
SRC=/tmp/snap-a2ee9df2
V=17.0.0
OUT=/tmp/t152-bars
mkdir -p $OUT
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  c=$D/lib/gcc/$V/$t/specs-config
  [ -s "$c" ] || { echo "FATAL: no specs-config for $t at $c"; exit 9; }
done
run () { # $1 target  $2 input  $3 tag  ... flags
  t=$1; in=$2; tag=$3; shift 3
  [ -s "$in" ] || { echo "FATAL: input missing or empty: $in"; exit 9; }
  ( cd $D/gcc && ./cc1 -quiet -nostdinc "$@" \
      -ftarget-config="$D/lib/gcc/$V/$t/specs-config" \
      "$in" -o $OUT/$tag.s ) 2> $OUT/$tag.err
  rc=$?
  if [ $rc != 0 ] || [ ! -s $OUT/$tag.s ]; then
    echo "$tag: FAIL rc=$rc"; sed -n 1,8p $OUT/$tag.err; return 1
  fi
  echo "$tag [$t] in=$in : $(wc -c < $OUT/$tag.s) bytes  md5 $(md5sum < $OUT/$tag.s | cut -c1-12)"
}
run x86_64-pc-linux-gnu "$SRC/scratchpad/big.c" x86-big -O2
