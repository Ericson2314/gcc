#!/bin/sh
# The codegen bars for the target_* layout sweep, in MY build dir.
# Every input path is quoted with every byte count: `-S' emits a `.file'
# directive, so a byte count is evidence about a FILENAME unless the input is
# named beside it (PRINCIPLES 6).
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b-ad827eb24f334c52d-pair}
V=17.0.0
OUT=$D/mtsw-bars
mkdir -p "$OUT"

got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D configured from '$got', not $SRC"; exit 9; }

run () { # $1 target  $2 input  $3 tag  ... flags
  t=$1; in=$2; tag=$3; shift 3
  c=$D/lib/gcc/$V/$t/specs-config
  [ -s "$c" ] || { echo "FATAL: no specs-config for $t at $c"; exit 9; }
  [ -s "$in" ] || { echo "FATAL: input missing or empty: $in"; exit 9; }
  (cd "$D/gcc" && ./cc1 -quiet -nostdinc "$@" \
     -ftarget-config="$c" "$in" -o "$OUT/$tag.s") 2> "$OUT/$tag.err"
  rc=$?
  if [ $rc != 0 ] || [ ! -s "$OUT/$tag.s" ]; then
    echo "$tag: FAIL rc=$rc"; sed -n 1,8p "$OUT/$tag.err"; return 1
  fi
  echo "$tag [$t] in=$in : $(wc -c < "$OUT/$tag.s") bytes  md5 $(md5sum < "$OUT/$tag.s" | cut -c1-12)"
}

run x86_64-pc-linux-gnu "$SRC/scratchpad/big.c" x86-big -O2
