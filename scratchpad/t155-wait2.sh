#!/bin/sh
# #155 -- wait until the AFTER tree has enough per-base objects to score the
# definition-level arm, OR until the build stamps, whichever comes first.
#
# The definition-level arm does NOT need the link, so it can be taken long
# before cc1 exists.  s390 is the gate because it is the second definer of all
# five names #150 recorded.
set -u
A=/tmp/b-af064528c538fd406-4after
while true; do
  if [ -f "$A/after.rc" ]; then
    echo "AFTER stamped rc=$(cat "$A/after.rc")"
    exit 0
  fi
  n=$(ls "$A"/gcc/mt-s390/*.o 2>/dev/null | wc -l)
  m=$(ls "$A"/gcc/mt-rs6000/*.o 2>/dev/null | wc -l)
  if [ "$n" -ge 4 ] && [ "$m" -ge 4 ]; then
    echo "per-base objects ready: s390 $n, rs6000 $m -- definition arm scorable"
    exit 0
  fi
  sleep 60
done
