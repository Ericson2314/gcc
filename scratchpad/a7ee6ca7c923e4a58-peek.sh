#!/bin/sh
# Interim read of an IN-FLIGHT board.  Every row is by construction PARTIAL --
# a `.sum' being written looks exactly like a finished one, and the partial
# read is always the smaller, cleaner-looking number (mt-lib.sh's own note).
# So this prints the per-target `.rc'-less status loudly and is NEVER the
# source of a reported figure.
set -u
B=${1:?build dir}
echo "!! INTERIM -- these targets have no .rc stamp; do not quote these numbers"
for d in "$B"/gcc/testsuite.*/gcc/gcc.sum; do
  [ -f "$d" ] || continue
  t=$(basename "$(dirname "$(dirname "$d")")" | sed 's/^testsuite\.//')
  p=$(grep -c '^PASS: ' "$d")
  f=$(grep -c '^FAIL: ' "$d")
  u=$(grep -c '^UNSUPPORTED: ' "$d")
  s=$(grep -c 'gcc Summary' "$d")
  printf '%-28s PASS=%-7s FAIL=%-7s UNSUP=%-6s summary-marker=%s\n' "$t" "$p" "$f" "$u" "$s"
done
