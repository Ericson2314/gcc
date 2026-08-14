#!/bin/sh
# t32-dump.sh -- dump every configured back end's REAL macro set, through the
# tm-<base>.h chain the compiler actually reads.
#
# Same method as tgh-hdrmatrix.sh (preprocess tm-<base>.h with -dM) but it
# keeps the VALUE, not just definedness, because task #32 has to distinguish
# three cases a definedness matrix cannot:
#
#   - defined by all 48 with the SAME value  -> IDENTITY; converting it changes
#     nothing and proves nothing (brief's own warning).
#   - defined by all 48 with DIFFERENT values -> a real leak.
#   - defined by some and not others         -> a real leak of the other shape,
#     where the shared `#ifdef' is decided by the primary.
#
# usage: t32-dump.sh <builddir> <outdir>
set -u
D=${1:?build dir}; O=${2:?out dir}
SRC=$(sed -n 's/.*running configure.*//p' /dev/null; echo "${SRC:-}")
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc missing"; exit 9; }
command -v cpp >/dev/null || { echo "FATAL: cpp not on PATH (dev shell?)"; exit 9; }
mkdir -p "$O"
rm -f "$O"/*.m "$O"/*.err

SNAP=$(sed -n "s#^  \\\$ \\(/[^ ]*\\)/configure .*#\\1#p" "$D/config.log" | head -1)
[ -n "$SNAP" ] || { echo "FATAL: cannot read srcdir from $D/config.log"; exit 9; }
echo "srcdir per config.log: $SNAP"

# Every back end's config/<dir> has to be on the include path, not just
# config/ itself.  Measured, not assumed: `tm-i386.h' includes the UNION
# `options-i386.h', which includes `config/arm/arm-opts.h', which includes
# "arm-isa.h" -- so preprocessing i386's chain needs ARM's directory.  With
# only -Iconfig, all 48 bases fail identically and the run reads as "nothing
# is defined anywhere".
CFGI=""
for d in "$SNAP"/gcc/config/*/; do CFGI="$CFGI -I$d"; done
[ -n "$CFGI" ] || { echo "FATAL: no config subdirs under $SNAP/gcc/config"; exit 9; }

# `tm-<base>.h' is NOT the only thing matching `tm-*.h'.  Measured in this
# build dir: 146 files match -- 48 back-end headers, 48 per-TRIPLE headers
# (tm-x86_64_pc_linux_gnu.h), and 49 each of tm-preds-* / tm-constrs-*.
# Globbing and filtering by prefix let the per-triple ones through and scored
# 97 "bases".  Enumerate the back ends the way the build does instead: a
# cpu_type directory under config/ carrying a .md file.
BE=""
for d in "$SNAP"/gcc/config/*/; do
  b=$(basename "$d")
  ls "$d" | grep -q '\.md$' || continue
  [ -f "$D/gcc/tm-$b.h" ] && BE="$BE $b"
done
[ -n "$BE" ] || { echo "FATAL: no tm-<base>.h for any cpu_type dir"; exit 9; }

echo > "$O/e.c"
N=0; BASES=""
for b in $BE; do
  f="$D/gcc/tm-$b.h"
  cpp -dM -I"$D/gcc" -I"$SNAP/gcc" -I"$SNAP/gcc/config" -I"$SNAP/include" \
      $CFGI -I"$D/gcc/include" -DIN_GCC -imacros "$f" "$O/e.c" \
      > "$O/$b.m" 2> "$O/$b.err"
  if [ -s "$O/$b.m" ]; then N=$((N+1)); BASES="$BASES $b"; else echo "UNREADABLE $b"; fi
done

# NON-VACUITY FIRST.  An all-empty read is indistinguishable from "nothing is
# defined anywhere" -- the reading that makes every site look already clean.
[ "$N" -gt 0 ] || { echo "FATAL: preprocessed NO base"; exit 9; }
CTL=$(grep -c . "$O/i386.m" 2>/dev/null || echo 0)
[ "$CTL" -gt 1000 ] || { echo "FATAL: i386 dump has $CTL macros -- cpp is not reading the chain"; exit 9; }
# And a both-sided control: two bases must DISAGREE about something known, or
# we are reading one header 48 times.
a=$(grep -c . "$O/aarch64.m"); [ "$a" -gt 1000 ] || { echo "FATAL: aarch64 dump $a"; exit 9; }
if cmp -s "$O/i386.m" "$O/aarch64.m"; then
  echo "FATAL: i386 and aarch64 dumps are IDENTICAL -- not per-base"; exit 9
fi
echo "non-vacuity: $N bases dumped; i386 $CTL macros; aarch64 $a; they differ"
echo "$BASES" | tr ' ' '\n' | grep . > "$O/bases.txt"
echo "bases=$(grep -c . "$O/bases.txt")"
