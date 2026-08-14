#!/bin/sh
# #173 -- ensure `#include "multi-target-base.h"' precedes the first
# `#include BASE_HEADER (...)' in every file that has one.
#
# t173-convert.sh asked whether the file contained that include ANYWHERE and
# skipped inserting it if so.  In a file whose existing include sat AFTER the
# line being converted, BASE_HEADER is then used undefined and cpp says
#
#   error: '#include' expects '"FILENAME"' or '<FILENAME>'
#
# followed by every name the un-included header would have supplied, which is
# what turned one ordering defect into 251 diagnostics.
#
# THE PATTERN IS ANCHORED ON THE DIRECTIVE, not on the word.  A first draft
# matched `BASE_HEADER (' anywhere and inserted an #include into the middle of
# target-insn.h's explanatory comment, which mentions the macro in prose.
set -e
cd "$(dirname "$0")/.."
n=0
for f in $(git grep -l '^#include BASE_HEADER (' -- gcc); do
  awk '
    BEGIN { inc = "#include \"multi-target-base.h\"" }
    $0 == inc { next }
    { line[++k] = $0 }
    END {
      first = 0;
      for (i = 1; i <= k; i++)
	if (line[i] ~ /^#include BASE_HEADER \(/) { first = i; break }
      for (i = 1; i <= k; i++) {
	if (i == first) print inc;
	print line[i];
      }
      if (first == 0) print inc;
    }' "$f" > "$f.t173" && mv "$f.t173" "$f"
  n=$((n + 1))
done
echo "checked $n file(s)"

bad=0
for f in $(git grep -l '^#include BASE_HEADER (' -- gcc); do
  u=$(grep -n '^#include BASE_HEADER (' "$f" | head -1 | cut -d: -f1)
  i=$(grep -n '^#include "multi-target-base\.h"' "$f" | head -1 | cut -d: -f1)
  if [ -z "$i" ] || [ "$i" -gt "$u" ]; then
    echo "OUT OF ORDER: $f (include $i, first use $u)"
    bad=$((bad + 1))
  fi
done
echo "files using BASE_HEADER before its header: $bad"
[ "$bad" = 0 ]
