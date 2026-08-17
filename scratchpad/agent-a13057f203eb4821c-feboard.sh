#!/bin/sh
# The front-end board: run mtcheck.sh once per TOOL on one target, preserving
# each tool's artefacts before the next run destroys them.
#
# `mtcheck.sh' writes `testsuite.<triple>/<tool>/<tool>.sum' -- the tool name
# is in the path, so unlike the per-.exp case the runs do not overwrite each
# other.  What they DO overwrite is `check-<triple>.rc' and `check-<triple>.out',
# which is why both are copied to a per-tool name here BEFORE the next tool
# starts.  INSTRUMENTS.md: the `.rc' stamp says a run FINISHED; it does not say
# the file still belongs to that run.
#
# usage: MT_TOOLS_<triple>=<bin> agent-a13057f203eb4821c-feboard.sh <builddir> <triple> <tool>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}; T=${2:?triple}; shift 2
[ $# -ge 1 ] || { echo "FATAL: name at least one tool"; exit 9; }
OUT=$B/feboard; mkdir -p "$OUT"
for TOOL in "$@"; do
  echo "################################ $TOOL"
  rm -f "$B/check-$T.rc"
  MT_CHECK_TOOL=$TOOL MT_COMPILE_ONLY=1 \
    sh "$S/mtcheck.sh" "$B" "$T" > "$OUT/$TOOL.out" 2>&1
  rc=$?
  echo "$rc" > "$OUT/$TOOL.rc"
  echo "$TOOL rc=$rc"
  # Copy the artefacts under a per-tool name while they are still this run's.
  for f in sum log; do
    src="$B/gcc/testsuite.$T/$TOOL/$TOOL.$f"
    [ -f "$src" ] && cp "$src" "$OUT/$TOOL.$f"
  done
  tail -3 "$OUT/$TOOL.out"
done
echo "artefacts in $OUT"
