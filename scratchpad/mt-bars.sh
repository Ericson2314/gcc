#!/bin/sh
# mt-bars.sh -- the x86_64 -O2 codegen bar on scratchpad/big.c.
#
# THE SURVIVOR OF 14 `*-bars.sh'.  This is the branch's strongest regression
# detector: after 688b3afe25d it reads 12369 bytes / md5 378fc33c1e70 at 2, 3,
# 4 and 11 bases, BYTE FOR BYTE, so it is no longer base-count dependent and
# may be quoted at any base count.
#
# QUOTE EVERY BAR WITH THE COMMAND THAT PRODUCED IT.  Three times in one day a
# "disagreement" was one quantity read two ways (`wc -l' 230 vs `grep -c .'
# 222 on the same file).  Both commands are printed for the specs-config, and
# THE INPUT PATH IS PRINTED BESIDE EVERY BYTE COUNT -- `-S' emits a `.file'
# directive, so a byte count with no input named is partly evidence about a
# filename.
#
# usage: WANT_ANCHOR=<n> mt-bars.sh <builddir> [tag]
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}
TAG=${2:-bars}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
V=$(cat "$SRC/gcc/BASE-VER")
OUT="$D/$TAG"; mkdir -p "$OUT"

t=${MT_BAR_TARGET:-x86_64-pc-linux-gnu}
c="$D/lib/gcc/$V/$t/specs-config"
[ -s "$c" ] || mt_die "no specs-config for $t at $c (run mt-specs.sh)"
echo "specs-config $t: wc -l $(wc -l < "$c")  grep -c . $(grep -c . "$c")  md5 $(md5sum < "$c" | cut -c1-12)"

IN=${MT_BAR_INPUT:-$SRC/scratchpad/big.c}
[ -s "$IN" ] || mt_die "input missing: $IN"
[ -x "$D/gcc/cc1" ] || mt_die "no $D/gcc/cc1"
( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" \
    "$IN" -o "$OUT/x86-big.s" ) > "$OUT/x86-big.out" 2> "$OUT/x86-big.err"
r=$?
if [ "$r" != 0 ] || [ ! -s "$OUT/x86-big.s" ]; then
  echo "x86-big [$t] in=$IN : FAIL rc=$r  (anchor=$n)"
  sed -n 1,12p "$OUT/x86-big.err"
  exit 1
fi
echo "x86-big [$t] in=$IN : $(wc -c < "$OUT/x86-big.s") bytes  md5 $(md5sum < "$OUT/x86-big.s" | cut -c1-12)  (anchor=$n)"
echo "recorded bar: 12369 bytes  md5 378fc33c1e70"
