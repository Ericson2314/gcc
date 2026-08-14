#!/bin/sh
# #176 -- the amputation arm with a BASELINE arm in front of it.
#
# TWO CORRECTIONS TO t160-amputate.sh, both found by running it.
#
# 1. A FILE THAT DOES NOT COMPILE ANYWAY SCORES `FAIL' AND READS AS "NEEDS
#    tm.h".  The candidate list spans ten front ends and this build configures
#    `c,lto'; a `rust/' or `cobol/' source fails on its own missing generated
#    headers with `tm.h' present or absent.  t160-amputate.sh compiles only the
#    amputated copy, so it cannot tell that apart from a target-macro
#    revocation.  This script compiles the file UNMODIFIED first and scores
#    N/A-BASELINE when that fails -- the file is then simply not measurable in
#    this configuration, which is a result, not a revocation.
#
# 2. THE NEGATIVE CONTROL IS NOT VALID FOR EVERY FILE, and t160-amputate.sh's
#    banner ("every file must FAIL") overstates it.  Measured: with the
#    conversion layer amputated too, `real.cc' fails on `enum reg_class' but
#    `hooks.cc' still PASSES -- correctly, because `hooks.cc' consumes nothing
#    from either channel.  So the control does not partition into "arm works"
#    and "arm broken"; it partitions the PASSes into two kinds, and BOTH
#    authorise the deletion:
#
#      CONTROL-FAIL  the TU does use the conversion layer, and the layer --
#                    not `tm.h' -- is what carries it.  This is the arm
#                    demonstrating it can fail.
#      CONTROL-PASS  the TU needs nothing from `tm.h' OR the layer.  The
#                    strongest warrant there is, by a different argument.
#
#    Reported separately rather than summed, so a run with ZERO control-fails
#    is visible: that would mean no file exercised the layer and the arm
#    proved nothing about it.
#
# usage: t176-amp2.sh <outfile> <file-relative-to-gcc>...
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
D=$W/b-a7cee-before
SRC=$W/snap-before
OUT=${1:?output file}; shift
WANT=${WANT_ANCHOR:-49}

grep -q "$SRC/configure" "$D/config.log" || { echo "FATAL: $D not from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "$WANT" ] \
  || { echo "FATAL: snapshot anchor is not $WANT"; exit 9; }

A=$D/t176-amp; mkdir -p "$A"
if [ ! -s "$A/recipe.txt" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" \
    | grep -m1 -- '-o cfgexpand\.o' > "$A/recipe.txt"
fi
RECIPE=$(cat "$A/recipe.txt")
[ -n "$RECIPE" ] || { echo "FATAL: no recipe for cfgexpand.o"; exit 9; }
FLAGS=$(printf '%s\n' "$RECIPE" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //')
CXX=$(printf '%s\n' "$RECIPE" | awk '{print $1}')

: > "$OUT"
for f in "$@"; do
  b=$(echo "$f" | tr '/' '_')
  src=$SRC/gcc/$f
  [ -f "$src" ] || { printf 'MISSING        %s\n' "$f" >> "$OUT"; continue; }
  ID=$(dirname "$src")

  # ARM 0 -- BASELINE.  Unmodified, in this build's real recipe.
  if ! sh "$S/eb-shell.sh" "cd $D/gcc && $CXX $FLAGS -I$ID -o $A/$b.base.o -c $src" \
       > /dev/null 2> "$A/$b.base.err"; then
    why=$(grep -m1 -E 'error:|fatal error:' "$A/$b.base.err" | sed 's/^.*error: //')
    printf 'N/A-BASELINE   %-50s %s\n' "$f" "$why" >> "$OUT"; continue
  fi

  # The amputated copy, with the removal asserted rather than assumed.
  cut=$A/$b.cut.cc
  sed 's|^[ \t]*#[ \t]*include[ \t]*"tm\.h".*$|/* tm.h include AMPUTATED */|' "$src" > "$cut"
  grep -q 'tm.h include AMPUTATED' "$cut" \
    || { echo "FATAL: $f -- amputation removed nothing"; exit 9; }

  # ARM 1 -- tm.h gone, conversion layer present.
  if ! sh "$S/eb-shell.sh" "cd $D/gcc && $CXX $FLAGS -I$ID -o $A/$b.o -c $cut" \
       > /dev/null 2> "$A/$b.err"; then
    why=$(grep -m1 -E 'error:' "$A/$b.err" | sed 's/^.*error: //')
    printf 'NEEDS-TM       %-50s %s\n' "$f" "$why" >> "$OUT"; continue
  fi

  # Did tm.h actually leave, or does another header still reach it?
  sh "$S/eb-shell.sh" "cd $D/gcc && $CXX $FLAGS -I$ID -E -dM -o $A/$b.dM $cut" \
     > /dev/null 2>&1 || true
  if grep -q '^#define GCC_TM_H' "$A/$b.dM" 2>/dev/null; then
    printf 'STILL-REACHES  %-50s tm.h arrives through another header\n' "$f" >> "$OUT"; continue
  fi
  n=$(wc -l < "$A/$b.dM" 2>/dev/null || echo 0)
  [ "$n" -gt 1000 ] || { echo "FATAL: $f dumped only $n macros -- read nothing"; exit 9; }

  # ARM 2 -- the same, with the conversion layer amputated as well.
  if sh "$S/eb-shell.sh" \
       "cd $D/gcc && $CXX $FLAGS -DGCC_MULTI_TARGET_MACROS_H -I$ID -o $A/$b.ctl.o -c $cut" \
       > /dev/null 2> "$A/$b.ctl.err"; then
    printf 'DELETE-CLEAN   %-50s (needs neither tm.h nor the layer)\n' "$f" >> "$OUT"
  else
    printf 'DELETE-VIALAYER %-49s (layer carries it: %s)\n' "$f" \
      "$(grep -m1 -E 'error:' "$A/$b.ctl.err" | sed 's/^.*error: //' | cut -c1-40)" >> "$OUT"
  fi
done

echo "=== $OUT ==="
awk '{print $1}' "$OUT" | sort | uniq -c | sort -rn
