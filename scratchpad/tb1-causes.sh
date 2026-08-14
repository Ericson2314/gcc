#!/bin/sh
# CAUSES, not counts: what the compiler actually SAID, per target.
#
# The scan-assembler board shows most tests never reach the scan -- they die
# with "excess errors" or an ICE first -- so the useful output is the top
# diagnostic TEXTS and ICE SITES, each of which names a file and a line and is
# a reproducer.  Read from the merged gcc.log (the .sum carries the verdict but
# not the message).
set -u
B=${1:?build dir}; shift
for T in "$@"; do
  LOG="$B/gcc/testsuite.$T/gcc/gcc.log"
  echo
  echo "################ $T"
  [ -f "$LOG" ] || { echo "  no log"; continue; }
  echo "-- top ICE sites:"
  grep -o 'internal compiler error: [^\\]*' "$LOG" \
    | sed 's/internal compiler error: //' | sed 's/[0-9]\{4,\}/N/g' \
    | sort | uniq -c | sort -rn | head -10
  echo "-- top error: texts (numbers and identifiers folded):"
  grep -o "error: .*" "$LOG" \
    | sed -e "s/'[^']*'/'X'/g" -e 's/[0-9][0-9]*/N/g' \
    | sort | uniq -c | sort -rn | head -12
done
