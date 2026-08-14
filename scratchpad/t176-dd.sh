#!/bin/sh
# #176 -- the deps-diff over this task's two 47-back-end builds.
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
for a in before after; do
  [ -f "$W/b-a7cee-$a/make-top.rc" ] \
    || { echo "FATAL: b-a7cee-$a has no .rc stamp -- log may be mid-write"; exit 9; }
done
echo "before: $(cat "$W/b-a7cee-before/make-top.rc") rc, $(find "$W/b-a7cee-before/gcc" -name '*.o' | wc -l) objects"
echo "after : $(cat "$W/b-a7cee-after/make-top.rc") rc, $(find "$W/b-a7cee-after/gcc" -name '*.o' | wc -l) objects"
exec sh "$S/t173-depsdiff.sh" "$W/b-a7cee-before" "$W/b-a7cee-after"
