#!/bin/sh
# #176 -- block until the amputation sweep has scored every candidate.
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
N=$(wc -l < "$W/cand.txt")
while [ "$(wc -l < "$W/amp-all.txt")" -lt "$N" ]; do sleep 30; done
echo "COMPLETE $(wc -l < "$W/amp-all.txt")/$N"
awk '{print $1}' "$W/amp-all.txt" | sort | uniq -c | sort -rn
