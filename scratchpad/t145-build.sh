#!/bin/sh
# #145 -- build the 48-back-end tree and record the diagnostic corpus.
# -k so every back end is attempted; make's FAILING-TARGET lines are the only
# valid attribution (PRINCIPLES section 1) -- never the nearest preceding
# compile line, which is invalid under -j.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${D:-/tmp/b-a88fe2f04579b6092}
T=${1:-multi-target-objs}
sh "$S/eb-shell.sh" "cd $D/gcc && make -k -j8 $T" > "$D/build-$T.out" 2> "$D/build-$T.err" || true
echo "rc recorded, not scored.  stdout $(wc -l < "$D/build-$T.out") lines, stderr $(wc -l < "$D/build-$T.err") lines"
