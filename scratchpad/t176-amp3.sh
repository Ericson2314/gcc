#!/bin/sh
# #176 -- SECOND PASS: for a TU that still needs something after `tm.h' goes,
# find the SMALLEST honest replacement.
#
# WHY THIS IS NOT A WEAKENING OF THE FIRST PASS.  `tm.h' is five channels
# (PRINCIPLES), and two of them are TARGET-NEUTRAL:
#
#   options.h              generated from EVERY configured back end's `.opt'
#                          files.  A TU including it directly gets no primary's
#                          answer -- there is no per-base version to get wrong.
#   multi-target-macros.h  this branch's conversion layer.  Names `targetm_cdata',
#                          `mt_*()' and `MULTI_TARGET_UNION_*' and never a back
#                          end; it is what the converted macros now resolve
#                          THROUGH.
#
# So a file failing on `OPT_E' or on `MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER'
# is not a file that needs the back end's header chain.  It is a file with a
# MISSING INCLUDE, whose absence `tm.h' was covering.  Naming the neutral
# header it actually wants is strictly more honest than including all five
# channels to get one.
#
# A file that still fails after both neutral headers DOES read the back end's
# chain, and is left alone and reported by cause -- that residue is the real
# conversion work and must not be hidden inside a "fixed" count.
#
# Every accepted outcome is still required to have LOST tm.h (`GCC_TM_H'
# undefined in `-E -dM'), so a remedy that merely reaches tm.h by another road
# scores STILL-REACHES rather than success.
#
# usage: t176-amp3.sh <outfile> <file-relative-to-gcc>...
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

A=$D/t176-amp3; mkdir -p "$A"
if [ ! -s "$A/recipe.txt" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" \
    | grep -m1 -- '-o cfgexpand\.o' > "$A/recipe.txt"
fi
R=$(cat "$A/recipe.txt"); [ -n "$R" ] || { echo "FATAL: no recipe"; exit 9; }
FLAGS=$(printf '%s\n' "$R" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //')
CXX=$(printf '%s\n' "$R" | awk '{print $1}')

# Try one replacement text; echo OK on success.
try () {  # $1=file $2=tag $3=replacement-line(s)
  _f=$1; _t=$2; _r=$3
  _n=$(echo "$_f" | tr '/' '_')
  _c=$A/$_n.$_t.cc
  awk -v r="$_r" \
    '/^[ \t]*#[ \t]*include[ \t]*"tm\.h"/ { print r; next } { print }' \
    "$SRC/gcc/$_f" > "$_c"
  grep -q '#include *"tm\.h"' "$_c" && { echo NO; return; }
  sh "$S/eb-shell.sh" \
     "cd $D/gcc && $CXX $FLAGS -I$(dirname "$SRC/gcc/$_f") -o $A/$_n.$_t.o -c $_c" \
     > /dev/null 2> "$A/$_n.$_t.err" || { echo NO; return; }
  sh "$S/eb-shell.sh" \
     "cd $D/gcc && $CXX $FLAGS -I$(dirname "$SRC/gcc/$_f") -E -dM -o $A/$_n.$_t.dM $_c" \
     > /dev/null 2>&1 || true
  grep -q '^#define GCC_TM_H' "$A/$_n.$_t.dM" && { echo STILL; return; }
  echo OK
}

: > "$OUT"
for f in "$@"; do
  [ -f "$SRC/gcc/$f" ] || { printf 'MISSING       %s\n' "$f" >> "$OUT"; continue; }
  r=$(try "$f" del "/* tm.h include removed */")
  [ "$r" = OK ]    && { printf 'DELETE        %-46s\n' "$f" >> "$OUT"; continue; }
  [ "$r" = STILL ] && { printf 'STILL-REACHES %-46s\n' "$f" >> "$OUT"; continue; }
  r=$(try "$f" opt '#include "options.h"')
  [ "$r" = OK ] && { printf 'NEUTRAL-OPTS  %-46s options.h alone suffices\n' "$f" >> "$OUT"; continue; }
  r=$(try "$f" lay '#include "multi-target-macros.h"')
  [ "$r" = OK ] && { printf 'NEUTRAL-LAYER %-46s the conversion layer alone suffices\n' "$f" >> "$OUT"; continue; }
  r=$(try "$f" both '#include "options.h"\n#include "multi-target-macros.h"')
  [ "$r" = OK ] && { printf 'NEUTRAL-BOTH  %-46s\n' "$f" >> "$OUT"; continue; }
  why=$(grep -m1 -E 'error:' "$A/$(echo "$f" | tr '/' '_').both.err" 2>/dev/null \
        | sed 's/^.*error: //' | cut -c1-70)
  printf 'REAL-TARGET   %-46s %s\n' "$f" "$why" >> "$OUT"
done
echo "=== $OUT ==="
awk '{print $1}' "$OUT" | sort | uniq -c | sort -rn
