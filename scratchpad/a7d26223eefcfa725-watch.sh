#!/bin/sh
# Emit each scoring row as it lands, and SAY SO if the scorer dies.
#
# The failure arm matters as much as the progress arm: a finished run and a
# scorer killed by the machine both stop producing rows, and from outside they
# are the same silence.  PRINCIPLES records exactly this -- a culled run leaves
# a stale stamp beside a partial artefact and reads as complete.
R=${1:-/tmp/w-a7d26223eefcfa725/rows.txt}
prev=0
while true; do
  n=$(grep -vc '^#' "$R" 2>/dev/null)
  [ -n "$n" ] || n=0
  if [ "$n" -gt "$prev" ]; then
    grep -v '^#' "$R" | tail -n $((n - prev))
    prev=$n
  fi
  if [ "$n" -ge 47 ]; then echo "ALL 47 ROWS LANDED"; break; fi
  if ! pgrep -f 'acda89931a903ec27-score' > /dev/null; then
    echo "SCORER GONE at $n/47 rows (load $(cut -d' ' -f1 /proc/loadavg))"
    break
  fi
  sleep 120
done
