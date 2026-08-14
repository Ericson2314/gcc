#!/bin/sh
# #176 -- drive one arm end to end: snapshot, configure 47 bases, build.
# usage: t176-go.sh <before|after> <snapdir-suffix>
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
ARM=${1:?before or after}
export WANT_ANCHOR=${WANT_ANCHOR:?set WANT_ANCHOR}
SNAP=$W/snap-$ARM
D=$W/b-a7cee-$ARM
LIST=$(cat "$W/list47.txt")
SRC=$SNAP sh "$S/t176-conf.sh" "$D" "$LIST"
sh "$S/t176-topbuild.sh" "$D"
