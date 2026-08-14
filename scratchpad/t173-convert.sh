#!/bin/sh
# #173 -- rewrite a plain `#include "<stem>.h"' to `#include BASE_HEADER
# (<stem>.h)' in the files named on stdin, adding `#include
# "multi-target-base.h"' ahead of the first one if the file has not already
# got it.
#
# ONLY for sources that are compiled ONCE PER BACK END.  A file compiled once
# has no MT_BASE and BASE_HEADER is the wrong answer for it; see
# scratchpad/T173-BASE-HEADER.md for the classification and why.
#
# usage: t173-convert.sh <stem> < list-of-paths-relative-to-tree-root
set -e
cd "$(dirname "$0")/.."
STEM=${1:?stem, e.g. tm or tm_p}
n=0
while read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || { echo "FATAL: no such file $f"; exit 9; }
  grep -q "^#include \"$STEM\.h\"" "$f" || { echo "skip (no plain include): $f"; continue; }
  awk -v stem="$STEM" '
    BEGIN { plain = "#include \"" stem ".h\""; done = 0 }
    { lines[NR] = $0; if ($0 == "#include \"multi-target-base.h\"") hasbase = 1 }
    END {
      for (i = 1; i <= NR; i++) {
	if (lines[i] == plain) {
	  if (!hasbase && !done) print "#include \"multi-target-base.h\"";
	  print "#include BASE_HEADER (" stem ".h)";
	  done = 1;
	  continue;
	}
	print lines[i];
      }
    }' "$f" > "$f.t173" && mv "$f.t173" "$f"
  n=$((n + 1))
done
echo "converted $n file(s) for stem $STEM"
