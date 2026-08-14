#!/bin/sh
# #176 -- run t176-amp2.sh over the whole candidate list.
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
exec sh "$S/t176-amp2.sh" "$W/amp-all.txt" $(cat "$W/cand.txt")
