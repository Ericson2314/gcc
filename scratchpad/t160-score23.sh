#!/bin/sh
# Task #160: score t141-delete-ready.txt (the 23 DIRECT includers of the
# Class A 39) against a t160-amputate.sh run.
# usage: t160-score23.sh <amputate-output> <list>
set -e
A=${1:?amputate output}
L=${2:?list}
n=0
while read f; do
  [ -n "$f" ] || continue
  n=$((n + 1))
  printf '  %-46s %s\n' "$f" "$(awk -v F="$f" '$2 == F { print $1; exit }' "$A")"
done < "$L"
echo "--- $n files; verdicts:"
while read f; do
  [ -n "$f" ] || continue
  awk -v F="$f" '$2 == F { print $1; exit }' "$A"
done < "$L" | sort | uniq -c
