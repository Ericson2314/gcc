#!/bin/sh
# Compare the generated multi-target artefacts between two build dirs.
A=$1; B=$2
rc=0
for f in multi-target.manifest multi-target-common.mk multi-target-common.h multi-target-spec-functions.h; do
  printf '%-32s ' "$f"
  if test ! -f "$A/$f"; then echo "MISSING in $A"; rc=1; continue; fi
  if test ! -f "$B/$f"; then echo "MISSING in $B"; rc=1; continue; fi
  if test ! -s "$A/$f"; then echo "EMPTY in $A -- refusing to score"; rc=1; continue; fi
  if diff -q "$A/$f" "$B/$f" > /dev/null 2>&1; then
    echo "IDENTICAL  md5=`md5sum < "$B/$f" | cut -c1-12`"
  else
    echo "*** DIFFERS ***"; rc=1
  fi
done
echo "--- targets named in each manifest ---"
printf 'A: '; grep '^target ' "$A/multi-target.manifest" | tr '\n' ' '; echo
printf 'B: '; grep '^target ' "$B/multi-target.manifest" | tr '\n' ' '; echo
echo "OVERALL rc=$rc"
exit $rc
