#!/bin/sh
# agent-ae59966cf819d72ef-eltbodies.sh -- HOW MANY DISTINCT ANSWERS does each
# case-vector macro have across the 47 real header chains?
#
# PRINCIPLES: "a count is not the divergence".  38 definers is not evidence the
# 38 disagree -- `ELIMINABLE_REGS' leaks between bases that both have exactly
# four pairs.  This prints the BODIES.
#
# Same `cpp -dM -imacros tm-<base>.h' mechanism as tgh-hdrmatrix.sh, i.e. the
# chain the compiler actually reads, not a `config/' directory grep (which
# scores `ASM_OUTPUT_CASE_LABEL' at 7 definers when elfos.h makes it 40).
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
W=$(mktemp -d); trap 'rm -rf "$W"' 0

BASES=""
for d in "$SRC"/gcc/config/*/; do
  b=$(basename "$d")
  ls "$d" | grep -q '\.md$' || continue
  [ -f "$D/gcc/tm-$b.h" ] && BASES="$BASES $b"
done
[ -n "$BASES" ] || { echo "FATAL: no tm-<base>.h in $D/gcc"; exit 9; }

for b in $BASES; do
  : > "$W/e.c"
  cpp -dM -I"$D/gcc" -I"$SRC/gcc" -I"$SRC/gcc/config" -I"$SRC/include" \
      -I"$D/gcc/include" -DIN_GCC -imacros "$D/gcc/tm-$b.h" "$W/e.c" \
      > "$W/$b.m" 2>/dev/null
done
[ -s "$W/i386.m" ] || { echo "FATAL: i386 dump empty -- cpp is not reading the chain"; exit 9; }
c=$(grep -c . "$W/i386.m"); [ "$c" -gt 1000 ] || { echo "FATAL: i386 dump $c macros"; exit 9; }
echo "non-vacuity: i386 dump $c macros over $(echo $BASES | wc -w) bases"
echo

for m in ${MACROS:-ASM_OUTPUT_ADDR_VEC_ELT ASM_OUTPUT_ADDR_DIFF_ELT ASM_OUTPUT_CASE_LABEL}; do
  : > "$W/bodies"
  for b in $BASES; do
    body=$(sed -n "s/^#define $m[ (]//p" "$W/$b.m" | head -1)
    [ -n "$body" ] || continue
    printf '%s\t%s\n' "$body" "$b" >> "$W/bodies"
  done
  nb=$(cut -f1 "$W/bodies" | sort -u | grep -c .)
  nd=$(grep -c . "$W/bodies")
  i386body=$(sed -n "s/^#define $m[ (]//p" "$W/i386.m" | head -1)
  echo "== $m: $nd definers, $nb DISTINCT bodies"
  [ -n "$i386body" ] && echo "   i386 (what all 47 shared reads get): $i386body"
  echo "   the other bodies, with how many bases each:"
  cut -f1 "$W/bodies" | sort | uniq -c | sort -rn | head -8 | sed 's/^/     /'
  echo
done
