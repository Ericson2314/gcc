#!/bin/sh
# #139 -- WHERE the class-(c) head macros are used in shared code, per file.
#
# Same population rule as t137-rank.sh (gcc/, minus config/ testsuite/ and the
# ada interface), so the totals here are comparable with t137-ranking.txt.
#
# CONTROLS, because a per-file count that silently reads zero is exactly the
# shape this project keeps manufacturing:
#   positive -- UNITS_PER_WORD must total >= 200 (t137 measured 267)
#   negative -- a name that does not exist must total 0
# Both are printed; the script exits 9 if either fails.
set -u
SRC=$(cd "$(dirname "$0")/.." && pwd)
cd "$SRC" || exit 9

count () {   # count <macro> -- prints "file count" lines, most-used first
  grep -rn "\\b$1\\b" gcc --include='*.cc' --include='*.h' \
    | grep -v '^gcc/config/' | grep -v testsuite | grep -v '^gcc/ada/' \
    | cut -d: -f1 | sort | uniq -c | sort -rn
}
total () { count "$1" | awk '{s+=$1} END {print s+0}'; }

pos=$(total UNITS_PER_WORD)
neg=$(total ZZ_NO_SUCH_MACRO_ZZ)
echo "control positive UNITS_PER_WORD total=$pos (t137 measured 267)"
echo "control negative ZZ_NO_SUCH_MACRO_ZZ total=$neg"
[ "$pos" -ge 200 ] || { echo "FATAL: positive control read $pos, instrument is broken"; exit 9; }
[ "$neg" -eq 0 ] || { echo "FATAL: negative control read $neg, pattern matches too much"; exit 9; }

for m in "$@"; do
  echo
  echo "=== $m  total=$(total "$m")"
  count "$m" | head -20
done
