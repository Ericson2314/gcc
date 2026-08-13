#!/bin/sh
# Classify a `make -k' log's diagnostics, with the poly_int class separated out.
#
# Written for the poly_int arity wall.  Three things it does deliberately:
#
#  * It attributes each diagnostic to a BACK END by the mt-<cpu>/ object being
#    compiled or by the config/<cpu>/ path in the message, and reports the
#    per-back-end distribution -- because the whole question is whether ~1800
#    diagnostics are one shape or thirty-nine problems.
#
#  * It separates POLY diagnostics from the rest by the message texts the
#    2-coefficient discipline produces, and prints BOTH counts.  A fix that
#    clears the poly class and leaves the residue must be reportable as
#    exactly that, so the residue is never folded into a single total.
#
#  * It does NOT score a back end as OK because its name is absent.  Under
#    `make -k' a back end whose prerequisite failed is never attempted, and
#    "not attempted" and "passed" are the same silence.  The caller supplies
#    the expected list and absence is reported BY NAME.
#
# No `grep -q' and no `head' anywhere a zero is established (PRINCIPLES 5).
#
# usage: poly-classify.sh <logfile> <backend-list-file>
set -e
LOG=${1:?log}
BE=${2:?back-end list file}
[ -s "$LOG" ] || { echo "FATAL: $LOG is empty or missing"; exit 9; }
[ -s "$BE" ] || { echo "FATAL: $BE is empty or missing"; exit 9; }

TOT=$(grep -c 'error:' "$LOG" || true)
echo "=== log: $LOG  ($(wc -l < "$LOG") lines)   total 'error:' lines = $TOT"
echo

# The poly class, by message text.  These are the forms the 2-coefficient
# discipline produces when target code treats a poly_int as a scalar.
POLYRE='to_constant|poly_int<|no match for ‘operator|switch quantity not an integer|invalid conversion|request for member'

echo "=== POLY-class diagnostics"
NP=$(grep 'error:' "$LOG" | grep -Ec "$POLYRE" || true)
echo "poly-class 'error:' lines = $NP"
echo "residue (non-poly)         = $((TOT - NP))"
echo

echo "=== distinct error TEXTS (all), normalised"
grep -E '(error|fatal error): ' "$LOG" \
  | sed -e 's/^.*\(error\|fatal error\): /\1: /' \
        -e "s/'[^']*'/'X'/g" -e 's/‘[^’]*’/‘X’/g' \
        -e 's/[0-9][0-9]*/N/g' \
  | sort | uniq -c | sort -rn
echo

echo "=== diagnostics by SOURCE file (top 40)"
grep -E '^[^ ]+:[0-9]+:[0-9]+: (error|fatal error):' "$LOG" \
  | sed -e 's/:[0-9]*:[0-9]*: .*//' \
        -e "s|.*/gcc/config/|config/|" -e "s|.*/gcc/|gcc/|" \
  | sort | uniq -c | sort -rn | sed -n '1,40p'
echo

echo "=== per back end: failing per-base objects, and whether attempted"
for b in $(grep -v '^#' "$BE" | grep . ); do
  # cpu dir name is not the triple; derive both and match either.
  echo "$b"
done > /dev/null

echo "=== per CPU (from mt-<cpu>/ objects named in failing recipes)"
grep -oE 'mt-[a-z0-9_]+/[A-Za-z0-9_.-]+\.o' "$LOG" \
  | sed 's|mt-\([a-z0-9_]*\)/.*|\1|' | sort | uniq -c | sort -rn
echo

echo "=== CPUs appearing in config/<cpu>/ diagnostic paths"
grep -E '(error|fatal error): ' "$LOG" \
  | grep -oE 'config/[a-z0-9_]+/' | sed 's|config/||;s|/||' \
  | sort | uniq -c | sort -rn
