#!/bin/sh
# #124 -- stock-compare against /tmp/b-stock, with an ABSOLUTE big.c and this
# task's own build dir.  $1 is a tag for the output directory, so a pre-edit
# and a post-edit run cannot overwrite each other.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b129}
TAG=${1:-run}
MT="$B" OUT="/tmp/sc129-$TAG" IN="$S/big.c" \
  bash "$S/stock-compare.sh" > "/tmp/sc129-$TAG.log" 2> "/tmp/sc129-$TAG.err"
rc=$?
echo "stock-compare rc=$rc  (log /tmp/sc129-$TAG.log, err /tmp/sc129-$TAG.err)"
tail -22 "/tmp/sc129-$TAG.log"
echo "stderr lines: $(wc -l < "/tmp/sc129-$TAG.err")"
exit $rc
