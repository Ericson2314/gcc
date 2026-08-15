#!/bin/sh
# a5764a65f9eec0063 -- is the x86_64 `-g' output really unchanged?
#
# `mt-bars.sh' compiles `$SRC/scratchpad/big.c', i.e. a path inside the
# SNAPSHOT directory, and the snapshot is named after the build.  So
# `/tmp/snap-...-fix' and `/tmp/snap-...-fix3' differ by one character, that
# path is embedded in the debug info (DW_AT_name / DW_AT_comp_dir), and the
# `-g' md5 MUST differ for a reason that has nothing to do with the compiler.
# The `-O2' bar has no debug info and so is immune, which is why it matched.
#
# This compiles ONE constant absolute path with both compilers, so the only
# thing that can differ is the compiler.  If the md5s still differ, the change
# is real and the path story is wrong.
set -u
A=${A:?first build dir}
B=${B:?second build dir}
W=${W:-/tmp/w-a5764a65f9eec0063/gcheck}
SRCF=$(cd "$(dirname "$0")" && pwd)/big.c
MEMCAP=$(cd "$(dirname "$0")" && pwd)/tb1-memcap.sh
[ -f "$SRCF" ] || { echo "FATAL: no $SRCF"; exit 9; }
mkdir -p "$W"
T=x86_64-pc-linux-gnu

for tag in a b; do
  case $tag in a) D=$A ;; b) D=$B ;; esac
  CFG=$D/lib/gcc/17.0.0/$T/specs-config
  [ -f "$CFG" ] || { echo "FATAL: no specs-config in $D"; exit 9; }
  sh "$MEMCAP" 8000000 "$D/gcc/xgcc" -B"$D/gcc/" -ftarget-config="$CFG" \
     -O2 -g -S "$SRCF" -o "$W/$tag.s" > "$W/$tag.out" 2> "$W/$tag.err"
  r=$?
  [ "$r" = 0 ] || { echo "FATAL($tag): rc=$r"; sed -n 1,5p "$W/$tag.err"; exit 9; }
  [ -s "$W/$tag.s" ] || { echo "FATAL($tag): empty .s"; exit 9; }
done

ma=$(md5sum < "$W/a.s" | cut -c1-12)
mb=$(md5sum < "$W/b.s" | cut -c1-12)
echo "input (constant for both): $SRCF"
echo "  A=$A   -O2 -g  $(wc -c < "$W/a.s") bytes  md5 $ma"
echo "  B=$B   -O2 -g  $(wc -c < "$W/b.s") bytes  md5 $mb"
if [ "$ma" = "$mb" ]; then
  echo "IDENTICAL -- the mt-bars.sh -g difference was the snapshot PATH, not the compiler."
else
  echo "DIFFERENT -- the change is real; diff follows:"
  diff "$W/a.s" "$W/b.s" | head -40
fi
