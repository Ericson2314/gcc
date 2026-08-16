#!/bin/sh
# Are the 776 named aarch64 regressions from the virtual-regno work GONE at tip?
#
# THE QUESTION IS BY NAME, NOT BY COLUMN.  A97CFF7619D3CABD9-VIRTUAL-REGNO.md
# records aarch64 going 338728/26294 -> 338215/27352 across that change, +271
# named progressions and -776 named regressions, every one of them the
# `*adddi3_poly_1' splitter becoming REACHABLE and then failing for want of the
# `const_poly_int' fix.  Columns cannot answer this: the two changes also move
# how many results some tests produce.
#
# Sets are keyed on (name, occurrence), as sc-diff.sh and mt-namediff.sh are,
# because a .sum carries the same NAME more than once and `sort -u' would drop
# rows from one side only -- into exactly the column being reported.
#
# NON-VACUITY IS BUILT IN AND RUNS FIRST.  A lookup that finds nothing looks
# identical to a lookup that finds everything fixed.  Two controls:
#   * the regression set must be exactly 776 -- if the two archived sums do not
#     reproduce that number, the disagreement is reported and nothing is
#     claimed;
#   * a SECOND set (PASS in unfixed, still PASS in fix2) is looked up through
#     the identical pipeline, so the instrument is shown able to report both
#     "PASS at tip" and "not PASS at tip" on the same run.
set -u
export LC_ALL=C
UNFIXED=${1:?aarch64 sum before the virtual-regno fix}
FIX2=${2:?aarch64 sum after it}
TIP=${3:?aarch64 sum at tip}

for f in "$UNFIXED" "$FIX2" "$TIP"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" \
    || { echo "FATAL: $f has no '=== gcc Summary' -- truncated, not a board"; exit 9; }
done

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

# (name, occurrence) -> status.  Only the result kinds a .sum line starts with.
key () {
  sed -n 's/^\(PASS\|XPASS\|FAIL\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\|WARNING\): //p' "$1" \
    | awk '{ n=$0; c[n]++; printf "%s\t%d\n", n, c[n] }' | sort
}
status () {
  awk -v OFS='\t' '{
      if (match($0, /^(PASS|XPASS|FAIL|XFAIL|UNSUPPORTED|UNRESOLVED|ERROR|WARNING): /)) {
        s = substr($0, 1, RLENGTH-2); n = substr($0, RLENGTH+1);
        c[n]++; print n, c[n], s
      }
    }' "$1" | sort -t"$(printf '\t')" -k1,2
}

status "$UNFIXED" > "$TD/u"
status "$FIX2"    > "$TD/f"
status "$TIP"     > "$TD/t"
for x in u f t; do
  [ -s "$TD/$x" ] || { echo "FATAL: $x parsed to nothing -- the instrument read no results"; exit 9; }
done
echo "parsed rows: unfixed $(wc -l < "$TD/u")  fix2 $(wc -l < "$TD/f")  tip $(wc -l < "$TD/t")"

j () { join -t"$(printf '\t')" -j 1 "$1" "$2"; }
# collapse (name,occ) into one join key
kf () { awk -F'\t' -v OFS='\t' '{ print $1 "\x01" $2, $3 }' "$1" | sort; }
kf "$TD/u" > "$TD/uk"; kf "$TD/f" > "$TD/fk"; kf "$TD/t" > "$TD/tk"

# REGRESSED = PASS in unfixed, present but NOT PASS in fix2.
j "$TD/uk" "$TD/fk" \
  | awk -F'\t' '$2=="PASS" && $3!="PASS" { print $1 "\t" $3 }' > "$TD/reg"
NREG=$(wc -l < "$TD/reg")
# CONTROL = PASS in unfixed AND PASS in fix2 (the negative-control population).
j "$TD/uk" "$TD/fk" \
  | awk -F'\t' '$2=="PASS" && $3=="PASS" { print $1 }' > "$TD/ctl"
NCTL=$(wc -l < "$TD/ctl")

echo
echo "REGRESSED (PASS unfixed -> NOT PASS fix2): $NREG   [the document records 776]"
echo "CONTROL   (PASS unfixed -> PASS fix2):     $NCTL"
if [ "$NREG" != 776 ]; then
  echo "*** The archived sums do not reproduce 776.  Reporting the disagreement"
  echo "*** rather than scoring against a number this run cannot confirm."
fi
[ "$NREG" -gt 0 ] || { echo "FATAL: empty regression set -- nothing to look up"; exit 9; }

lookup () { # $1 = key list, $2 = label
  cut -f1 "$1" | sort > "$TD/q"
  join -t"$(printf '\t')" -j 1 "$TD/q" "$TD/tk" > "$TD/r"
  tot=$(wc -l < "$TD/q"); found=$(wc -l < "$TD/r")
  p=$(awk -F'\t' '$2=="PASS"' "$TD/r" | wc -l)
  echo "$2: $tot asked, $found found at tip, PASS $p, NOT PASS $((found-p)), absent $((tot-found))"
  awk -F'\t' '$2!="PASS" { print $2 }' "$TD/r" | sort | uniq -c | sort -rn | head -8 | sed 's/^/    /'
}

echo
lookup "$TD/reg" "THE REGRESSION SET AT TIP"
echo
lookup "$TD/ctl" "THE CONTROL SET AT TIP (proves the lookup can report both ways)"

echo
echo "the regression set's fix2 statuses, for reference:"
cut -f2 "$TD/reg" | sort | uniq -c | sort -rn | sed 's/^/    /'
