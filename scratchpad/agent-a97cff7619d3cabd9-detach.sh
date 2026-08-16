#!/bin/sh
# agent-a97cff7619d3cabd9-detach.sh -- run mtcheck.sh DETACHED, so that the
# agent harness reaping its background task list cannot kill a run that is
# hours in.  Measured: two `mtcheck.sh' aarch64 runs were stopped an hour in
# with status `killed', and a killed run leaves no `.rc' -- which is the same
# observation as "still running", the absent-artefact-vs-absent-mechanism shape
# again.  Poll for `$B/check-<triple>.rc'; its presence is the only pass signal.
#
# usage: agent-a97cff7619d3cabd9-detach.sh <builddir> <triple> [makeflags]
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}; T=${2:?triple}; J=${3:--j6}
case "$B" in */b-a97cff7619d3cabd9*) ;; *) echo "FATAL: not this worktree's build dir"; exit 9 ;; esac
V=MT_TOOLS_$(printf '%s' "$T" | tr - _)
rm -f "$B/check-$T.rc"
setsid sh -c "MT_COMPILE_ONLY=1 MT_MAKEFLAGS=$J $V=/tmp/tools-a97cff7619d3cabd9/bin \
  WANT_ANCHOR=52 sh $S/mtcheck.sh $B $T" > "$B/detach-$T.log" 2>&1 &
echo "detached: $B $T $J  -> $B/detach-$T.log ; wait for $B/check-$T.rc"
