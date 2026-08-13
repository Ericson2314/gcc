#!/bin/sh
# Group a `make -k' log's failures by BACK END and by CAUSE.
#
# The point of the census is the DISTRIBUTION -- learning that thirty back ends
# share four causes rather than that there are thirty problems -- so this
# refuses to print a bare total.
#
# Two things it deliberately does NOT do:
#
#  * It does not score a back end as OK because its name is absent from the
#    log.  With `make -k' a back end whose prerequisite failed is never
#    ATTEMPTED, and "not attempted" and "passed" are the same silence.  The
#    caller must supply the expected back-end list so absence is reported as
#    NOT-ATTEMPTED, by name.
#  * It does not use `head' or `grep -q' anywhere a zero is being established.
#
# usage: mtN-classify.sh <logfile> <backend-list-file>
set -e
LOG=${1:?log}
BE=${2:?back-end list file}
[ -s "$LOG" ] || { echo "FATAL: $LOG is empty or missing"; exit 9; }
[ -s "$BE" ] || { echo "FATAL: $BE is empty or missing"; exit 9; }

echo "=== log: $LOG  ($(wc -l < "$LOG") lines)"
echo
echo "=== compiler diagnostics, by file"
grep -E '^[^ ]+:[0-9]+:[0-9]+: (error|fatal error):' "$LOG" \
  | sed -e 's/:[0-9]*:[0-9]*: /: /' \
  | sed -e "s|.*/gcc/config/|config/|" \
  | sort | uniq -c | sort -rn || true
echo
echo "=== distinct error TEXTS (the cause classes)"
grep -E '(error|fatal error): ' "$LOG" \
  | sed -e 's/^.*\(error\|fatal error\): /\1: /' \
  | sed -e "s/'[^']*'/'X'/g" \
  | sort | uniq -c | sort -rn || true
echo
echo "=== make-level failures"
grep -E "^make.*(Error|No rule to make target)" "$LOG" | sort | uniq -c | sort -rn || true
echo
echo "=== per back end"
for b in $(grep -v '^#' "$BE" | grep . ); do
  n=$(grep -c -- "$b" "$LOG" || true)
  echo "$b mentions=$n"
done
