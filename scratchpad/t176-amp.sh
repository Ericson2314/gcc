#!/bin/sh
# #176 -- run the #160 amputation arm against this task's before-build.
# Thin wrapper so the long absolute paths live in one place.
# usage: [MT_CONTROL=1] t176-amp.sh <file-relative-to-gcc>...
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
export WANT_ANCHOR=${WANT_ANCHOR:-49}
exec sh "$S/t160-amputate.sh" "$W/b-a7cee-before" "$W/snap-before" "$@"
