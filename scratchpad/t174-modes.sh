#!/bin/sh
# #174 -- READ THE CLASS-RUN ENDPOINTS OUT OF EVERY BASE'S insn-modes.h.
#
# The deliverable arm.  `MIN_MODE_<CLASS>' is used two ways on this branch:
# as a WALK START (fixed in #164 by moving such walks to
# GET_CLASS_NARROWEST_MODE) and as an INDEX ORIGIN / an array BOUND, which is
# what this measures.  An origin that differs between a shared TU and a
# per-base TU indexes one struct at two different elements, silently -- which
# is worse than a size mismatch, because a size mismatch has a witness.
#
# No compile is needed: the numbers are in the generated headers.  The shared
# header is `insn-modes.h'; each base's is `insn-modes-<base>.h' in the build
# ROOT (NOT `<base>-inc/', which the BASE_HEADER conversion has not reached
# for this stem -- an earlier draft of this script looked there, found no
# directories, and would have reported "nothing to compare" as a clean run).
#
# usage: t174-modes.sh <builddir>
set -e
D=${1:?build dir}
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
G=$D/gcc
[ -f "$G/insn-modes.h" ] || { echo "FATAL: no $G/insn-modes.h"; exit 9; }

# `insn-modes-inline-<base>.h' also matches the obvious glob and carries none
# of these constants; including it would add a context whose every value is
# empty, which reads as agreement.
BASEH=$(ls "$G"/insn-modes-*.h | grep -v '/insn-modes-inline-')
nb=$(echo "$BASEH" | grep -c .)

# NON-VACUITY.  An all-empty read is indistinguishable from "the constants
# agree", which is the answer this arm exists to disprove.
[ "$nb" -ge 2 ] || { echo "FATAL: $nb per-base headers; nothing to compare"; exit 9; }
echo "== per-base headers: $nb"

dump () {   # $1 = header, $2 = label
  awk -v L="$2" '
    /^  (MIN|MAX)_MODE_[A-Z_]* = E_[A-Za-z0-9_]*mode,/ {
      split($0, a, /[ ,]+/); print L, a[2], a[4]; next }
    /^#define NUM_MODE_[A-Z_]+ / { print L, $2, $3 }
  ' "$1"
}

: > /tmp/t174-all.txt
dump "$G/insn-modes.h" SHARED >> /tmp/t174-all.txt
for d in $BASEH; do
  b=$(basename "$d" .h); b=${b#insn-modes-}
  dump "$d" "$b" >> /tmp/t174-all.txt
done
n=$(grep -c . /tmp/t174-all.txt)
[ "$n" -gt 20 ] || { echo "FATAL: read only $n constants"; exit 9; }
echo "== readings: $n over $((nb + 1)) contexts"

echo "== constants that are NOT identical in every context"
awk '{ v[$2] = v[$2] " " $1 "=" $3
       if (!($2 in seen)) { order[++n] = $2; seen[$2] = 1 }
       c[$2 SUBSEP $3] = 1 }
     END { bad = 0
           for (i = 1; i <= n; i++) { k = order[i]; nv = 0
             for (p in c) { split (p, q, SUBSEP); if (q[1] == k) nv++ }
             if (nv > 1) { print "  " k ":" v[k]; bad++ } }
           if (!bad) print "  (none)" }' /tmp/t174-all.txt

echo "== AARCH64_APPROX_MODE shift width (aarch64-protos.h:495; UB at >= 64)"
awk '/^  (MIN|MAX)_MODE_(FLOAT|VECTOR_FLOAT) = /{split($0,a,/[ ,]+/); v[a[2]]=a[4]}
     /^  E_[A-Za-z0-9_]*mode(,| =)/{split($0,a,/[ ,=]+/); if (!(a[2] in ord)) ord[a[2]]=++i}
     END { f = ord[v["MAX_MODE_FLOAT"]] - ord[v["MIN_MODE_FLOAT"]] + 1
           g = ord[v["MAX_MODE_VECTOR_FLOAT"]] - ord[v["MIN_MODE_VECTOR_FLOAT"]] + 1
           if (f <= 0 || g <= 0) { print "  FATAL: could not read the runs"; exit 9 }
           printf "  scalar floats=%d  vector floats=%d  highest shift=%d\n", f, g, f+g-1 }' \
    "$G/insn-modes.h"
