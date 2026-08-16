#!/bin/sh
# STAGE 3 -- rank causes by HOW MANY BACK ENDS CARRY THEM, not by how many
# results any one target loses.
#
# WHY THIS RANKING AND NOT THE PER-TARGET ONE.  Every defect this project has
# actually fixed was "one name, several authorities": a single cause reaching
# many back ends at once.  `AB1900D5279BA137F-BOARD.md` 7 ends by observing
# that none of its four top causes is shared between targets and calling that
# "four independent per-back-end investigations" -- but it only ever had FOUR
# targets to compare, and with four you cannot tell a shared cause from a
# coincidence.  With seventeen you can.  A cause on 12 back ends outranks a
# cause worth more results on one.
#
# THE DIAGNOSTIC IS TAKEN FROM THE TEST NAME, which DejaGnu annotates:
#   FAIL: gcc.c-torture/compile/foo.c  -O2  (internal compiler error: in X, at Y)
# so the `.sum' alone is enough and no log parsing is needed.  Note the
# consequence recorded on that board: an ICE row and its `(test for excess
# errors)' sibling are TWO rows for one failing compile, so these counts are
# ROW counts, not distinct-test counts, and are used only to rank.
#
# NON-VACUITY IS MANDATORY AND IT IS CHECKED.  If the instrument reports zero
# shared causes it must be able to show it read anything at all -- a back end
# with no assembler, one never attempted, and one that passes everything all
# produce an empty failure list.  So the script REFUSES when it parsed no
# `.sum' or found no FAIL rows anywhere, rather than printing an empty table.
set -u
OUT=${1:?artefact dir with <triple>.gcc.sum files}
n=$(ls "$OUT"/*.gcc.sum 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "FATAL: no *.gcc.sum in $OUT -- nothing was scored"; exit 9; }

TMP=/tmp/shared-$$; mkdir -p "$TMP"

# per target: PASS/FAIL totals, and the set of distinct diagnostics it carries
: > "$TMP/pairs"
printf '%-28s %8s %8s %8s %s\n' TARGET PASS FAIL UNSUP ICE-SITES
for f in "$OUT"/*.gcc.sum; do
  T=$(basename "$f" .gcc.sum)
  p=$(grep -c '^PASS: ' "$f")
  fl=$(grep -c '^FAIL: ' "$f")
  u=$(grep -c '^UNSUPPORTED: ' "$f")
  # normalise a diagnostic to a CAUSE key: the ICE site, or the bare kind.
  grep '^FAIL: ' "$f" \
    | sed -e 's/.*(internal compiler error: \(.*\))$/ICE \1/' \
          -e 's/^FAIL: .*(\(test for excess errors\))$/excess-errors/' \
          -e 's/^FAIL: .*(\(.*\))$/\1/' \
          -e 's/^FAIL: .*/unannotated/' \
    | sed -e 's/, at \(.*\)$/ at \1/' \
    | sort -u | sed "s|^|$T |" >> "$TMP/pairs"
  nice=$(grep -c 'internal compiler error' "$f")
  printf '%-28s %8s %8s %8s %s\n' "$T" "$p" "$fl" "$u" "$nice"
done

tot=$(grep -c . "$TMP/pairs")
if [ "$tot" = 0 ]; then
  echo
  echo "NON-VACUITY REFUSAL: $n .sum files parsed, ZERO FAIL rows in any of"
  echo "them.  That is either a genuinely clean board or a broken parser, and"
  echo "this script cannot tell the difference.  Refusing to print a cause"
  echo "table that would read as 'no shared causes found'."
  rm -rf "$TMP"; exit 9
fi

echo
echo "== CAUSES RANKED BY NUMBER OF BACK ENDS CARRYING THEM ($n targets scored)"
echo
printf '%-6s %s\n' BACKENDS CAUSE
awk '{ $1=""; sub(/^ /,""); print }' "$TMP/pairs" | sort | uniq -c \
  | sort -rn | head -40 \
  | while read -r c rest; do printf '%-6s %s\n' "$c" "$rest"; done

echo
echo "== the same causes, with WHICH back ends (top 12 shared)"
awk '{ k=$0; sub(/^[^ ]* /,"",k); print k "\t" $1 }' "$TMP/pairs" \
  | sort | awk -F'\t' '{ a[$1]=a[$1]" "$2; c[$1]++ } END { for (k in a) printf "%d\t%s\t%s\n", c[k], k, a[k] }' \
  | sort -rn | head -12 \
  | while IFS="$(printf '\t')" read -r c k who; do
      [ "$c" -gt 1 ] || continue
      echo "  [$c] $k"
      echo "      $who"
    done
rm -rf "$TMP"
