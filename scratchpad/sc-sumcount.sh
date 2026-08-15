#!/bin/sh
# sc-sumcount.sh -- print the six verdict columns of a gcc.sum, by exact path.
#
# WHY IT EXISTS RATHER THAN A `grep -c' AT THE CALL SITE.  Three refusals that
# the inline form kept omitting, each of which this project has already paid
# for once:
#
#   * the file must exist AND carry `=== gcc Summary'.  A .sum without its
#     summary is non-empty, greps clean, and is a truncated run -- and the
#     partial read is always the smaller, cleaner-looking number.
#   * the `.rc' stamp, when the caller names one, must be present.  The
#     summary marker is NOT sufficient: it passed on a sixth of an aarch64 run
#     whose 28948+18908+... block was internally consistent.
#   * a zero total is a REFUSAL, not a board of zeroes.
#
# usage: sc-sumcount.sh <gcc.sum> [<label>] [<rc-stamp>]
set -u
F=${1:?gcc.sum}
LAB=${2:-$F}
RC=${3:-}
[ -f "$F" ] || { echo "FATAL: no $F"; exit 9; }
if [ -n "$RC" ]; then
  [ -f "$RC" ] || { echo "FATAL: no $RC stamp -- the run did not finish"; exit 9; }
fi
grep -q '=== gcc Summary' "$F" \
  || { echo "FATAL: $F has no '=== gcc Summary' -- truncated run"; exit 9; }
p=$(grep -c '^PASS: ' "$F" || true)
f=$(grep -c '^FAIL: ' "$F" || true)
xp=$(grep -c '^XPASS: ' "$F" || true)
xf=$(grep -c '^XFAIL: ' "$F" || true)
u=$(grep -c '^UNSUPPORTED: ' "$F" || true)
ur=$(grep -c '^UNRESOLVED: ' "$F" || true)
tot=$((p+f+xp+xf+u+ur))
[ "$tot" -gt 0 ] || { echo "FATAL: $F scored 0 results"; exit 9; }
printf '%-46s %8s %8s %6s %6s %7s %8s\n' "$LAB" "$p" "$f" "$xp" "$xf" "$u" "$ur"
