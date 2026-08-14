#!/bin/sh
# The CONTROL bars: same tree, i386 + aarch64 only.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=/tmp/b-aa95b761351d960a4-pair
V=17.0.0
OUT=/tmp/mta7-pairbars
mkdir -p $OUT
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D configured from '$got', not $SRC"; exit 9; }
c=$D/lib/gcc/$V/x86_64-pc-linux-gnu/specs-config
[ -s "$c" ] || { echo "FATAL: no specs-config at $c"; exit 9; }
for pair in "big.c:x86-big" "rs6k-hello.c:x86-hello"; do
  in=$SRC/scratchpad/${pair%%:*}; tag=${pair##*:}
  [ -s "$in" ] || { echo "FATAL: missing input $in"; exit 9; }
  (cd $D/gcc && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" "$in" -o $OUT/$tag.s) 2> $OUT/$tag.err
  rc=$?
  if [ $rc != 0 ] || [ ! -s $OUT/$tag.s ]; then
    echo "PAIR $tag: FAIL rc=$rc"; sed -n 1,5p $OUT/$tag.err
  else
    echo "PAIR $tag in=$in : $(wc -c < $OUT/$tag.s) bytes  md5 $(md5sum < $OUT/$tag.s | cut -c1-12)"
  fi
done
