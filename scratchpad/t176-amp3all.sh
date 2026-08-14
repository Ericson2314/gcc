#!/bin/sh
# #176 -- second pass over every NEEDS-TM file from the first sweep.
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
exec sh "$S/t176-amp3.sh" "$W/amp3-all.txt" $(cat "$W/needs.txt")
