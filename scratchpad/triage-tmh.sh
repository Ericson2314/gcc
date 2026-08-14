#!/bin/sh
# Re-measure the tm.h populations PRINCIPLES quotes (248 / 101 / 4).
set -u
cd "$(dirname "$0")/../gcc" || exit 1
P='^[[:space:]]*#[[:space:]]*include[[:space:]]+"tm\.h"'
echo "anchor: $(grep -c MULTI_TARGET ../gcc/Makefile.in)"
echo -n "shared TUs+hdrs outside config/ including tm.h: "
grep -rlE "$P" --include=*.cc --include=*.c --include=*.h . | grep -v '^\./config/' | wc -l
echo -n "under config/ including tm.h: "
grep -rlE "$P" --include=*.cc --include=*.c --include=*.h ./config | wc -l
echo "--- the four shared headers ---"
for f in target.h backend.h cp/cp-tree.h m2/gm2-gcc/gcc-consolidation.h; do
  printf '%s: ' "$f"
  if [ -f "$f" ]; then grep -cE "$P" "$f"; else echo MISSING-FILE; fi
done
echo -n "BASE_HEADER (tm.h) call sites: "
grep -rl 'BASE_HEADER *(tm\.h)' . | wc -l
