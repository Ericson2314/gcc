#!/bin/sh
# #124 -- stock-compare against /tmp/b-stock, with an ABSOLUTE big.c and this
# task's own build dir.  $1 is a tag for the output directory, so a pre-edit
# and a post-edit run cannot overwrite each other.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b132}
TAG=${1:-run}
MT="$B" OUT="/tmp/sc132-$TAG" IN="$S/big.c" \
  bash "$S/stock-compare.sh" > "/tmp/sc132-$TAG.log" 2> "/tmp/sc132-$TAG.err"
rc=$?
echo "stock-compare rc=$rc  (log /tmp/sc132-$TAG.log, err /tmp/sc132-$TAG.err)"
tail -22 "/tmp/sc132-$TAG.log"
echo "stderr lines: $(wc -l < "/tmp/sc132-$TAG.err")"
exit $rc
