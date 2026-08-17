#!/bin/sh
# Front-end task launcher: detach a build so the agent harness cannot cull it.
# INSTRUMENTS.md: "a long run must be DETACHED (setsid nohup), not a harness
# background task" -- the harness killed two mtcheck runs mid-.exp.
# usage: agent-a13057f203eb4821c-run.sh <builddir> <tag> <make-target...>
set -eu
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; shift
TAG=${1:?tag}; shift
export SRC=${SRC:?set SRC}
export WANT_ANCHOR=${WANT_ANCHOR:?}
export MT_JOBS=${MT_JOBS:-8}
export MT_MAKE=${MT_MAKE:-}
rm -f "$D/$TAG.rc"
setsid nohup sh "$S/mt-build.sh" "$D" "$TAG" "$@" > "$D/$TAG.run" 2>&1 < /dev/null &
echo "launched pid=$! -> $D/$TAG.run  (stamp $D/$TAG.rc)"
