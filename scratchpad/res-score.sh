#!/bin/sh
# BEFORE/AFTER `error:' totals and per-cause histograms for the 47-back-end
# build, plus the count that actually matters here: HOW MANY BACK ENDS.
#
# ARM 0 IS THE NON-VACUITY ARM AND IT RUNS FIRST.  Every number below comes
# from a grep, and a grep that reads nothing scores 0 -- in the direction that
# says "fixed".  Both logs must exist, both must be non-empty, and the BEFORE
# log must contain at least one `error:' line, or this refuses to score.  A
# before-log with no errors cannot demonstrate an improvement no matter what
# the after-log says.
#
# usage: res-score.sh [builddir]
set -e
D=${1:-/tmp/b-af73bc3169a097677}
B=$D/base.err
A=$D/after.err

for f in "$B" "$A"; do
  [ -f "$f" ] || { echo "FATAL: $f does not exist"; exit 9; }
  [ -s "$f" ] || { echo "FATAL: $f is empty"; exit 9; }
done
nb=$(grep -c 'error:' "$B" || true)
[ "${nb:-0}" -gt 0 ] \
  || { echo "FATAL: BEFORE log has no 'error:' at all; nothing to improve on"; exit 9; }
echo "ARM 0 non-vacuity: before=$(wc -l < "$B") lines / $nb error:, after=$(wc -l < "$A") lines"

na=$(grep -c 'error:' "$A" || true)
echo
echo "error: lines            $nb -> ${na:-0}"

# A back end is counted by the DIRECTORY the failing file lives in -- a
# `config/<D>/' path or an `mt-<cpu>/' object dir.  NOT by the nearest
# preceding compile line, which is invalid under -j8 (PRINCIPLES s1).
bes () {
  grep 'error:' "$1" \
    | sed -e 's|.*/config/\([a-z0-9_]*\)/.*|\1|' -e 's|.*\bmt-\([a-z0-9_]*\)/.*|\1|' \
    | grep -x '[a-z0-9_]*' | sort -u
}
echo "back ends with an error $(bes "$B" | wc -l) -> $(bes "$A" | wc -l)"
echo "  before: $(bes "$B" | tr '\n' ' ')"
echo "  after:  $(bes "$A" | tr '\n' ' ')"

hist () {
  grep 'error:' "$1" | sed 's/.*error: //' | cut -c1-70 | sort | uniq -c | sort -rn
}
echo
echo "== BEFORE causes =="; hist "$B"
echo "== AFTER causes  =="; hist "$A"
echo
echo "== cause classes present AFTER but not BEFORE (a new class is a regression) =="
comm -13 <(hist "$B" | sed 's/^ *[0-9]* //' | sort -u) \
         <(hist "$A" | sed 's/^ *[0-9]* //' | sort -u) \
  | sed 's/^/  NEW: /'
echo
echo "back ends with at least one mt-<cpu>/*.o: $(ls -d "$D"/gcc/mt-*/ 2>/dev/null | wc -l)"
