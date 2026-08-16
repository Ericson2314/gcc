#!/bin/sh
# agent-a4568de8f522450d3-drive.sh -- configure+build the PRE and POST 47-base
# trees for the `ASM_DECLARE_FUNCTION_SIZE' conversion.
#
# PRE  = 4387bf9ce42 (multi-target-0 tip, my parent)
# POST = fe9cbaf5163 (the conversion)
#
# Both from IMMUTABLE `git archive' snapshots named for worktree AND sha
# (PRINCIPLES: a build dir re-reads its srcdir long after configure, so a
# snapshot path shared with another commit measures the wrong tree and says so
# with a green).
#
# The `.rc' stamp is written by mt-build.sh only after make returns; nothing
# downstream may score a log without it.
set -u
ID=agent-a4568de8f522450d3
W=$(cd "$(dirname "$0")/.." && pwd)
A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
export WANT_ANCHOR=$A
export MT_MAKEFLAGS=${MT_MAKEFLAGS:--j6}
LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep -v '^$' | paste -sd,)

echo "anchor=$A  jobs=$MT_MAKEFLAGS  bases=$(echo "$LIST" | tr ',' '\n' | wc -l)"

for pair in 4387bf9ce42:pre fe9cbaf5163:post; do
  sha=${pair%%:*}; tag=${pair##*:}
  S=/tmp/snap-$ID-$sha
  # mt-lib.sh derives the expected build-dir tag from THIS script's own name,
  # i.e. `a4568de8f522450d3' with no `agent-' prefix; the snapshots keep the
  # prefix because that is what the previous board used.  The guard fired on
  # the mismatch, which is it working.
  D=/tmp/b-${ID#agent-}-$tag
  [ -f "$S/SNAP-SHA" ] || { echo "FATAL: no snapshot $S"; exit 9; }
  echo "=== $tag  src=$S  build=$D"
  SRC=$S sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST" \
      > /tmp/b-${ID#agent-}-$tag-conf.log 2> /tmp/b-${ID#agent-}-$tag-conf.err
  rc=$?
  echo "  conf rc=$rc"
  [ $rc -eq 0 ] || { tail -20 /tmp/b-${ID#agent-}-$tag-conf.err; exit 9; }
  sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
  echo "  build rc=$? stamp=$(cat "$D/all-gcc.rc" 2>/dev/null || echo MISSING)"
done
echo "DRIVE DONE"
