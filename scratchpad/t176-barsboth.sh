#!/bin/sh
# #176 -- the x86_64 -O2 codegen bar on BOTH arms.  One-sided evidence cannot
# distinguish "unchanged" from "both arms changed the same way", so the before
# arm is re-measured here rather than quoted from PRINCIPLES.
set -u
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
export WANT_ANCHOR=${WANT_ANCHOR:-49}
for a in before after; do
  printf '%-7s ' "$a"
  sh "$S/t176-bars.sh" "$W/b-a7cee-$a" "$W/snap-$a" "bars-$a" 2>&1 | grep 'x86-big'
done
