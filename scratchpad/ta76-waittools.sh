#!/bin/sh
# Emit one line when t170-tools.sh has proved all seven cross assemblers.
n=0
while [ "$n" -lt 7 ]; do
  sleep 20
  n=$(grep -c . /tmp/tools-a76e99/MACHINES 2>/dev/null || echo 0)
done
echo "TOOLSDONE $n machines proved"
