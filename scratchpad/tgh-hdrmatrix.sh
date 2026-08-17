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

# The default population is `targhooks.cc's own `#ifdef' set, which is what
# this script was written for.  `MACROS' in the environment overrides it, so
# any other candidate list -- a leak census row, the jump-table family -- can be
# scored through the same real-header-chain mechanism instead of a directory
# grep.  That override is the whole reason this file was extended rather than
# copied: the defect it exists to avoid (elfos.h being invisible to a `config/'
# grep) is not specific to targhooks.cc's macros.
if [ -n "${MACROS:-}" ]; then
  MACROS=$(echo "$MACROS" | tr ' ,' '\n\n' | grep . | sort -u)
  echo "population: from the environment, $(echo "$MACROS" | grep -c .) macros"
else
  MACROS=$(sed -n 's/^#ifdef \([A-Z_][A-Z_0-9]*\)$/\1/p' "$SRC/gcc/targhooks.cc" \
           | grep -v '^HAVE_' | sort -u)
  echo "population: targhooks.cc #ifdefs, $(echo "$MACROS" | grep -c .) macros"
fi
[ -n "$MACROS" ] || { echo "FATAL: read no macros for the population"; exit 9; }

# `tm-<base>.h' is not the only `tm-*.h' the build writes: `tm-preds-<base>.h'
# and `tm-constrs-<base>.h' match the same glob and define none of these
# macros, so leaving them in makes every macro look under-defined by ~95
# spurious "bases".  Restrict to the real back ends, which are exactly the
# cpu_type directories under gcc/config that carry a .md file -- the same
# definition mta7-targhook-matrix.sh uses.
BASES=""
for d in "$SRC"/gcc/config/*/; do
  b=$(basename "$d")
  ls "$d" | grep -q '\.md$' || continue
  [ -f "$D/gcc/tm-$b.h" ] && BASES="$BASES $b"
done
BASES=$(echo $BASES | tr ' ' '\n' | sort)
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
[ -s "$WORK/i386.m" ] || { echo "FATAL: i386 dump empty -- cpp is not reading the chain"; exit 9; }
CTL=$(grep -c . "$WORK/i386.m")
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
  p=no
  has i386 "$m" && p=i386
  has aarch64 "$m" && p="$p,aarch64"
  printf '%-32s defined-by=%-3s primary=%-14s not-defined-by:%s\n' \
         "$m" "$n" "$p" "$(echo $miss)"
done

echo
echo "=== SILENT RISK, measured: a PRIMARY defines the macro and this base does not."
echo "    The shared targhooks.cc '#ifdef' is then TRUE for a reason that has"
echo "    nothing to do with this base, and it silently receives the primary's"
echo "    answer.  No ICE, no diagnostic."
NS=0; SB=""
for m in $MACROS; do
  { has i386 "$m" || has aarch64 "$m"; } || continue
  for b in $BASES; do
    [ -s "$WORK/$b.m" ] || continue
    has "$b" "$m" && continue
    echo "  $b $m"
    NS=$((NS + 1)); SB="$SB $b"
  done
done
echo "  silent pairs=$NS back ends=$(echo $SB | tr ' ' '\n' | sort -u | grep -c .)"
