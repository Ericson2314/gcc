#!/bin/sh
# agent-a018835bbcfad2e28-drive2.sh -- after mt-build.sh: cross tools, per-target
# specs, bars, then the testsuite once per named target.  DETACHED by the
# caller; the harness culls long background tasks and a culled run leaves a
# stale `.rc' beside a partial `gcc.sum'.
#
# ONE mtcheck AT A TIME.  Two runs in one build dir collide on `site.exp' and
# both write `gcc.log' to the same path, so the targets are a sequential loop
# here rather than parallel arms.
#
# usage: B=<builddir> drive2.sh <triple> [<triple> ...]
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
ID=agent-a018835bbcfad2e28
B=${B:?set B to the build dir}
TOOLS=${TOOLS:-/tmp/tools-$ID}
L=${L:-/tmp/drive2-$ID-$(basename "$B")}
mkdir -p "$L"
cd "$W" || exit 9

A=$(grep -c MULTI_TARGET gcc/Makefile.in)
[ "$A" = 52 ] || { echo "FATAL anchor=$A" > "$L/FATAL"; exit 9; }
export WANT_ANCHOR=$A
[ -f "$B/all-gcc.rc" ] && [ "$(cat "$B/all-gcc.rc")" = 0 ] \
  || { echo "FATAL: $B has no rc=0 build stamp" > "$L/FATAL"; exit 9; }

step () {
  echo "=== $1 $(date)" >> "$L/drive2.log"
  shift
  "$@" >> "$L/drive2.log" 2>&1
  rc=$?
  echo "rc=$rc" >> "$L/drive2.log"
  return $rc
}

step tools sh scratchpad/taa-tools.sh "$TOOLS" \
  || { echo tools > "$L/DRIVE2-FAILED"; exit 9; }
B="$B" TOOLS="$TOOLS" step specs sh scratchpad/taa-specs.sh \
  || { echo specs > "$L/DRIVE2-FAILED"; exit 9; }
step bars sh scratchpad/mt-bars.sh "$B"

for T in "$@"; do
  echo "=== check $T $(date)" >> "$L/drive2.log"
  # The stamp is REMOVED first: an `.rc' left by an earlier invocation cannot
  # be told from this one's, and it is what authorises the copy below.
  rm -f "$B/check-$T.rc"
  V=MT_TOOLS_$(printf '%s' "$T" | tr - _)
  env "$V=$TOOLS/bin" MT_COMPILE_ONLY=1 MT_MAKEFLAGS=-j6 \
    sh scratchpad/mtcheck.sh "$B" "$T" >> "$L/check-$T.log" 2>&1
  echo "check $T rc=$?" >> "$L/drive2.log"
  # preserve the artefacts before the next target overwrites gcc.sum/gcc.log
  if [ -f "$B/check-$T.rc" ]; then
    S=$B/testsuite.$T/gcc/gcc.sum
    [ -f "$S" ] && cp "$S" "$L/$T.sum"
    cp "$B/check-$T.rc" "$L/$T.rc"
  fi
done
echo "=== DRIVE2 DONE $(date)" >> "$L/drive2.log"
echo 0 > "$L/DRIVE2.rc"
