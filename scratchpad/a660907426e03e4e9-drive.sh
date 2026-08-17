#!/bin/sh
# Detached driver: build the 47-base tree, then run the specs probe for the two
# targets this task scores against, then the bars.  One detached process rather
# than three, so a harness cull cannot land between two steps and leave a
# stamped-but-stale artefact (INSTRUMENTS.md).
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=/tmp/b-a660907426e03e4e9
SRC=/tmp/snap-agent-a660907426e03e4e9-3f75b7f16a3
TOOLS=/tmp/tools-agent-a660907426e03e4e9

WANT_ANCHOR=55 MT_JOBS=12 sh "$S/mt-build.sh" "$B" all-gcc all-gcc
echo "build.rc=$(cat "$B/all-gcc.rc")"
[ "$(cat "$B/all-gcc.rc")" = 0 ] || exit 9
