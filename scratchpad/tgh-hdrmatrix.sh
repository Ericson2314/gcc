#!/bin/sh
# tgh-hdrmatrix.sh -- the targhook matrix measured against each back end's REAL
# header chain, not against a directory grep.
#
# WHY THIS EXISTS.  `mta7-targhook-matrix.sh' asks "does `gcc/config/<be>/'
# contain a `#define <MACRO>'?".  That is wrong in a direction that inflates the
# SILENT population badly, and the counterexample is a single file:
#
#     gcc/config/elfos.h:#define ASM_OUTPUT_EXTERNAL_LIBCALL ...
#     gcc/config/elfos.h:#define DWARF2_DEBUGGING_INFO ...
#
# `elfos.h' lives at `gcc/config/', NOT under any back end's directory, and is
# pulled into the tm.h chain of nearly every ELF target.  The directory grep
# cannot see it, so it scores 43 back ends as "does not define
# ASM_OUTPUT_EXTERNAL_LIBCALL" when most of them do define it, via elfos.h.
# Same for `tm-dwarf2.h', `darwin.h', `vx-common.h'.
#
# The build writes a real per-base `tm-<base>.h' whose include chain is the one
# the compiler actually reads.  Preprocessing it with `-dM' answers the question
# the grep was approximating.  This instrument can both add and remove pairs, so
# per PRINCIPLES section 4 ("when it can grant, make it exact") it is exact
# rather than over-broad.
#
# usage: tgh-hdrmatrix.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc missing"; exit 9; }

MACROS=$(sed -n 's/^#ifdef \([A-Z_][A-Z_0-9]*\)$/\1/p' "$SRC/gcc/targhooks.cc" \
         | grep -v '^HAVE_' | sort -u)
[ -n "$MACROS" ] || { echo "FATAL: read no #ifdef macros from targhooks.cc"; exit 9; }

BASES=$(ls "$D/gcc"/tm-*.h | sed 's|.*/tm-||; s|\.h$||' | grep -v '_' | sort)
[ -n "$BASES" ] || { echo "FATAL: no tm-<base>.h in $D/gcc"; exit 9; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0

# Dump each base's macro set once.
NOK=0
for b in $BASES; do
  echo > "$WORK/e.c"
  cpp -dM -I"$D/gcc" -I"$SRC/gcc" -I"$SRC/gcc/config" -I"$SRC/include" \
      -I"$D/gcc/include" -DIN_GCC -imacros "$D/gcc/tm-$b.h" "$WORK/e.c" \
      > "$WORK/$b.m" 2> "$WORK/$b.err"
  if [ -s "$WORK/$b.m" ]; then NOK=$((NOK + 1)); else echo "UNREADABLE $b"; fi
done

# NON-VACUITY, FIRST.  An all-empty dump is indistinguishable from "nothing is
# defined anywhere", which is the reading that makes every back end look clean.
[ "$NOK" -gt 0 ] || { echo "FATAL: preprocessed NO base successfully"; exit 9; }
CTL=$(grep -c . "$WORK/i386.m" 2>/dev/null || echo 0)
[ "$CTL" -gt 1000 ] || { echo "FATAL: i386 dump has only $CTL macros -- cpp is not reading the chain"; exit 9; }
echo "non-vacuity: $NOK/$(echo $BASES|wc -w) bases preprocessed; i386 dump $CTL macros"
echo

has () { grep -q "^#define $2\([ (]\)" "$WORK/$1.m"; }

echo "=== per-macro definer counts, measured through the real tm.h chain"
for m in $MACROS; do
  n=0; miss=""
  for b in $BASES; do
    [ -s "$WORK/$b.m" ] || continue
    if has "$b" "$m"; then n=$((n + 1)); else miss="$miss $b"; fi
  done
  printf '%-32s defined-by=%-3s not-defined-by:%s\n' "$m" "$n" "$(echo $miss)"
done
