#!/bin/sh
# t32-valueall.sh -- t32-value.sh's arm over the WHOLE live macro set.
#
# Same measurement, batched: one `cpp' run per base expanding every candidate
# at once, instead of one run per (base, macro).  48 runs rather than ~20,000,
# which is what makes the value-level arm affordable over the whole census
# rather than over a hand-picked dozen -- and hand-picking is how an identity
# macro survives into a conversion.
#
# usage: t32-valueall.sh <dumpdir> <snapshot-srcdir> <builddir> <macrolist> <out>
set -u
DUMP=${1:?dump dir}; SRC=${2:?snapshot srcdir}; D=${3:?build dir}
LIST=${4:?macro list}; OUT=${5:?out file}
W=$(mktemp -d); trap 'rm -rf "$W"' 0
CFGI=""
for d in "$SRC"/gcc/config/*/; do CFGI="$CFGI -I$d"; done
BASES=$(cat "$DUMP/bases.txt")
NM=$(grep -c . "$LIST")
[ "$NM" -gt 0 ] || { echo "FATAL: empty macro list"; exit 9; }

# THE LABEL MUST NOT BE MACRO-EXPANDED.  First draft emitted
# `MTVAL <name> <name>' and cpp expanded BOTH copies, so for every macro whose
# body contains a space the label was destroyed and the first token of the
# expansion was read as the macro's name.  It produced 814 "macros" from a
# 413-name list, with entries called `GR_REGS', `("arm7tdmi")' and
# `"\t.string\t"'.  Wrapping the label in a string literal makes it inert;
# cpp does not expand inside one.
awk '{printf "MTVAL \"%s\" %s\n", $0, $0}' "$LIST" > "$W/in.c"

NB=0
for b in $BASES; do
  cpp -x c++ -P -I"$D/gcc" -I"$SRC/gcc" -I"$SRC/gcc/config" -I"$SRC/include" \
      $CFGI -I"$D/gcc/include" -DIN_GCC -imacros "$D/gcc/tm-$b.h" "$W/in.c" \
      2>/dev/null | sed -n 's/^MTVAL //p' > "$W/$b.v"
  [ -s "$W/$b.v" ] && NB=$((NB+1))
done
# NON-VACUITY FIRST: an all-empty read makes every macro look like an identity.
[ "$NB" -ge 40 ] || { echo "FATAL: only $NB bases expanded"; exit 9; }
echo "non-vacuity: $NB bases expanded, $NM macros each"

cat "$W"/*.v | awk -v OUT="$OUT" '
  {
    if (!match($0, /^"[A-Za-z_][A-Za-z_0-9]*"/)) next
    n=substr($0, RSTART+1, RLENGTH-2)
    v=substr($0, RSTART+RLENGTH); gsub(/[ \t]/, "", v)
    # strip redundant outer parens: "(8)" and "8" are one value, and scoring
    # them as two is the identity trap committed by the instrument.
    while (v ~ /^\(.*\)$/) {
      inner=substr(v,2,length(v)-2)
      if (index(inner,"(")>0 || index(inner,")")>0) break
      v=inner
    }
    if (v == n) v="<NOT-EXPANDED:function-like>"
    if (!((n SUBSEP v) in seen)) { seen[n SUBSEP v]=1; nv[n]++; ex[n]=ex[n] "|" v }
    nb[n]++
  }
  END {
    for (n in nv) {
      k = (ex[n] ~ /NOT-EXPANDED/) ? "UNREADABLE-function-like" \
        : (ex[n] ~ /[A-Za-z_]/) \
          ? ((nv[n]==1) ? "IDENTITY-TEXT-OPTION-STATE" : "DIVERGENT-OPTION-STATE") \
          : ((nv[n]==1) ? "IDENTITY-BY-VALUE" : "DIVERGENT-BY-VALUE")
      printf "%s\t%s\t%d\t%d\t%s\n", k, n, nb[n], nv[n], substr(ex[n],2) > OUT
    }
  }'
echo "== value-level classification of $NM live macros"
awk -F'\t' '{c[$1]++} END {for (k in c) printf "  %-28s %d\n", k, c[k]}' "$OUT" | sort -k2 -rn
