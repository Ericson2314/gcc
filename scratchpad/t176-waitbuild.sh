#!/bin/sh
# #176 -- block until the after-build has written its `.rc' stamp.
# The stamp, not the log, is the completion signal: a log being written looks
# exactly like a log that finished (PRINCIPLES sec 4).
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
while [ ! -f "$W/b-a7cee-after/make-top.rc" ]; do sleep 60; done
echo "after build rc=$(cat "$W/b-a7cee-after/make-top.rc")"
echo "objects: $(find "$W/b-a7cee-after/gcc" -name '*.o' | wc -l)"
echo "error: lines: $(grep -c 'error:' "$W/b-a7cee-after/make-top.err" || true)"
