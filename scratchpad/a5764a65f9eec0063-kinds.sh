#!/bin/sh
# a5764a65f9eec0063 -- classify a .sum's FAILs per directory into the three
# kinds that need entirely different investigations, because the FAIL column
# does not distinguish them:
#
#   COMPILE  "(test for excess errors)"  -- the compiler refused the input
#   BODIES   "check-function-bodies"     -- it compiled and emitted wrong code
#   SCAN     "scan-assembler*"           -- ditto, single-pattern form
#
# usage: sh a5764a65f9eec0063-kinds.sh <gcc.sum> <dir-substring> [...]
set -u
S=${1:?sum file}; shift
[ -s "$S" ] || { echo "FATAL: $S absent or empty"; exit 9; }
# Non-vacuity: the file must contain at least one PASS and one FAIL, or the
# per-directory zeroes below cannot be distinguished from an unread file.
grep -q '^PASS' "$S" || { echo "FATAL: no PASS lines in $S"; exit 9; }

for d in "$@"; do
  tot=$(grep -c "$d" "$S" || true)
  [ "$tot" != 0 ] || { echo "=== $d : NO LINES AT ALL (not run?)"; continue; }
  p=$(grep '^PASS' "$S" | grep -c "$d" || true)
  f=$(grep '^FAIL' "$S" | grep -c "$d" || true)
  u=$(grep '^UNRESOLVED' "$S" | grep -c "$d" || true)
  echo "=== $d : PASS $p  FAIL $f  UNRESOLVED $u"
  grep '^FAIL' "$S" | grep "$d" | awk '
    /check-function-bodies/            { c["BODIES"]++;  next }
    /test for excess errors/           { c["COMPILE"]++; next }
    /scan-assembler/                   { c["SCAN"]++;    next }
                                       { c["OTHER"]++ }
    END { for (k in c) printf "      %-8s %6d\n", k, c[k] }' | sort -k2 -rn
done
