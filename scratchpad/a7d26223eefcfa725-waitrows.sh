#!/bin/sh
# Block until N scoring rows have landed (or the scorer dies).
R=/tmp/w-a7d26223eefcfa725/rows.txt
N=${1:-47}
while true; do
  n=$(grep -vc '^#' "$R" 2>/dev/null)
  [ -n "$n" ] || n=0
  [ "$n" -ge "$N" ] && { echo "REACHED $n"; exit 0; }
  pgrep -f 'acda89931a903ec27-score' > /dev/null || { echo "SCORER GONE at $n"; exit 1; }
  sleep 60
done
