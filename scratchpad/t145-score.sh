#!/bin/sh
# #145 -- score a build log: total `error:' lines, a per-CAUSE histogram, and
# how many BACK ENDS each cause covers.
#
# NON-VACUITY ARM FIRST.  Every arm below reads with grep, and "the greps read
# nothing" is indistinguishable from "there are no errors" -- which is the
# direction that manufactures a green.  So the script REFUSES to score unless
# it can first show it read a log that actually contains compile commands.
# An empty or truncated log is a broken measurement, not a clean build.
#
# ATTRIBUTION IS BY MAKE'S FAILING-TARGET LINES, never by the nearest
# preceding compile line: under -j8 one back end's command is followed by
# another job's errors (PRINCIPLES section 1).
set -u
L=${1:?build stderr log}
[ -f "$L" ] || { echo "FATAL: no such log: $L"; exit 9; }

# --- non-vacuity ------------------------------------------------------------
O=$(dirname "$L")/$(basename "$L" .err).out
[ -f "$O" ] || { echo "FATAL: no matching stdout log $O"; exit 9; }
ncmd=$(grep -c 'MT_BASE\|-o .*\.o' "$O")
if [ "$ncmd" -lt 100 ]; then
  echo "FATAL: $O shows only $ncmd compile-ish lines."
  echo "This log cannot support a claim about error counts: an all-empty read"
  echo "looks exactly like a clean build.  Refusing to score."
  exit 9
fi
echo "non-vacuity: $ncmd compile lines in $O  OK"

# --- totals -----------------------------------------------------------------
tot=$(grep -c 'error:' "$L" || true)
echo "TOTAL 'error:' lines: $tot"

# --- failing objects, by make's own failing-target lines --------------------
echo "--- failing targets (make's own attribution):"
grep -E "^make(\[[0-9]+\])?: \*\*\* \[" "$L" | sed 's/.*\[//; s/\].*//' | sort -u > /tmp/t145-failtargets.txt
echo "    distinct failing targets: $(wc -l < /tmp/t145-failtargets.txt)"
sed 's/^/      /' /tmp/t145-failtargets.txt | head -60

# Back ends: a per-base object is <stem>-<cpu>.o or lives in mt-<cpu>/.
echo "--- back ends implicated (from those target names):"
sed -e 's#.*mt-\([a-z0-9_]*\)/.*#\1#' -e 's#.*-\([a-z0-9_]*\)\.o$#\1#' \
    /tmp/t145-failtargets.txt | sort -u > /tmp/t145-failbases.txt
echo "    count: $(wc -l < /tmp/t145-failbases.txt)"
tr '\n' ' ' < /tmp/t145-failbases.txt; echo

# --- cause histogram --------------------------------------------------------
# Normalise: drop file/line, drop quoted identifiers, so one CAUSE is one row.
echo "--- cause histogram (normalised message, count, files):"
grep 'error:' "$L" \
  | sed -e 's/^[^ ]*: *//' -e "s/error: //" \
  | sed -e "s/[\`'\"‘][^\`'\"’]*[\`'\"’]/X/g" -e 's/[0-9][0-9]*/N/g' \
  | sort | uniq -c | sort -rn | head -40 | sed 's/^/    /'

# --- poly_int subset --------------------------------------------------------
echo "--- poly_int-class errors:"
np=$(grep 'error:' "$L" | grep -c 'poly_int\|poly_uint\|poly_offset\|to_constant\|is_constant\|NUM_POLY_INT_COEFFS\|fixed_size_mode' || true)
echo "    count: $np  (of $tot)"
grep 'error:' "$L" | grep 'poly_int\|poly_uint\|poly_offset\|to_constant\|is_constant\|NUM_POLY_INT_COEFFS\|fixed_size_mode' \
  | sed 's/:[0-9]*:[0-9]*:.*//' | sort | uniq -c | sort -rn | head -40 | sed 's/^/      /'
