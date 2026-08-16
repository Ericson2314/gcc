#!/bin/sh
# ICE sites ranked BOTH ways at once: how many back ends carry each, and how
# many FAIL rows it costs across all of them.
#
# The two orderings genuinely disagree, and that is the point.  A site on six
# back ends worth 71 rows and a site on one back end worth 6,000 are different
# kinds of work item, and a single ranking hides whichever it is not sorted
# by.  `shared.sh` answers "how many back ends"; this answers both, so the
# disagreement is visible instead of being a function of which script was run.
set -u
OUT=${1:?artefact dir}
n=$(ls "$OUT"/*.gcc.sum 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "FATAL: no *.gcc.sum in $OUT"; exit 9; }
TMP=/tmp/icerank-$$; mkdir -p "$TMP"
for f in "$OUT"/*.gcc.sum; do
  T=$(basename "$f" .gcc.sum)
  sed -n 's/.*internal compiler error: \(.*\))$/\1/p' "$f" \
    | sed 's/, at /  at /' | sed "s|\$|\t$T|"
done > "$TMP/all"
rows=$(grep -c . "$TMP/all")
[ "$rows" -gt 0 ] || { echo "FATAL: zero ICE rows parsed from $n .sum files -- refusing to print an empty ranking"; rm -rf "$TMP"; exit 9; }
echo "== $rows ICE rows over $n scored back ends"
echo
printf '%-4s %-6s %s\n' BE ROWS SITE
awk -F'\t' '{c[$1]++; if(!seen[$1 FS $2]++) b[$1]++} END {for(k in c) printf "%d\t%d\t%s\n", b[k], c[k], k}' "$TMP/all" \
  | sort -k1,1nr -k2,2nr | head -25 \
  | while IFS="$(printf '\t')" read -r nb nr site; do
      printf '%-4s %-6s %s\n' "$nb" "$nr" "$site"
    done
rm -rf "$TMP"
