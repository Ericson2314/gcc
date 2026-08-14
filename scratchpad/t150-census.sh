#!/bin/sh
# #150 -- the build-failure census for a many-back-end build.
#
# Reports CAUSES and BACK ENDS, not lines.  PRINCIPLES section 1: single
# defects on this branch have produced 974, 725, 606 and 94 diagnostics, so a
# line count is the least informative number available.
#
# ATTRIBUTION IS BY MAKE'S FAILING-TARGET LINES, NOT BY THE NEAREST PRECEDING
# COMPILE LINE.  Under -j8 i386's command is followed by visium's errors from
# another job; the nearest-line rule is invalid and has been got wrong here
# before.
#
# usage: t150-census.sh <builddir> <make-err-file>
set -u
B=${1:?build dir}
E=${2:?make stderr file}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
[ -f "$E" ] || { echo "FATAL: no $E"; exit 9; }

# ARM 0, AND IT RUNS FIRST: refuse to score if the greps read nothing.
# An empty stderr and a stderr this script cannot parse look identical, and
# both read as "no errors", which is the shape of success.
lines=$(grep -c . "$E" || true)
[ "$lines" -gt 0 ] || {
  echo "REFUSING TO SCORE: $E is empty.  That is either a clean build or a"
  echo "harness that captured nothing, and this script cannot tell them apart."
  echo "Confirm by artefact: does $B/gcc/cc1 exist?"
  ls -la "$B/gcc/cc1" 2>&1 | tail -1
  exit 9
}
echo "arm 0 ok: $E has $lines lines"
echo

nerr=$(grep -c 'error:' "$E" || true)
echo "== totals"
echo "  stderr lines : $lines"
echo "  'error:'     : $nerr"

echo
echo "== failing make targets (the VALID attribution under -j)"
grep -oE "\*\*\* \[[^]]*\] Error" "$E" | sed 's/.*\[//; s/\] Error//' \
  | sort -u > "$B/t150-failed-targets.txt" || true
echo "  distinct failing targets: $(grep -c . "$B/t150-failed-targets.txt" || true)"
head -40 "$B/t150-failed-targets.txt" | sed 's/^/    /'

echo
echo "== BACK ENDS implicated (how many, not how many lines)"
grep -oE 'mt-[a-z0-9_]+/|config/[a-z0-9_]+/|insn-[a-z]+-[a-z0-9_]+' "$E" \
  | sed 's|mt-||; s|config/||; s|/||; s|insn-[a-z]*-||' \
  | sort -u > "$B/t150-backends.txt" || true
echo "  distinct back-end names appearing: $(grep -c . "$B/t150-backends.txt" || true)"

echo
echo "== per-CAUSE histogram (the error text, stripped of file and identifier)"
grep 'error:' "$E" \
  | sed 's/^[^ ]*error: //' \
  | sed "s/'[^']*'/'X'/g; s/\"[^\"]*\"/\"X\"/g; s/[0-9][0-9]*/N/g" \
  | sort | uniq -c | sort -rn | head -25 | sed 's/^/  /'
