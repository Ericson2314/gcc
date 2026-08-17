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
# A DIRECTORY PER LAUNCH, AND THE STAMPS OF *THIS LAUNCH'S* TOOLS CLEARED --
# NEITHER A SHARED DIRECTORY NOR AN `rm -rf' OF ONE.  Both wrong versions were
# run, and each destroyed something the other protected:
#
#   * Sharing one directory and clearing only the tool about to run: a first
#     launch died at the anchor assert and left six `<tool>.rc' files; the
#     relaunch was still on its FIRST tool when a waiter polling for
#     `algol68.rc' -- the LAST tool -- saw the PREVIOUS launch's stamp and
#     reported the board complete.
#   * `rm -rf "$OUT"' fixes that and introduces the trap INSTRUMENTS.md
#     already records: a second launch covering FOUR tools deleted the
#     finished `gfortran' and `algol68' artefacts of a six-tool launch.  Their
#     figures survived only because they had been copied aside BY HAND.  A fix
#     for one instance of "the stale file reads as a live one" recreated
#     another instance of it, in the same file, within the hour.
#
# So: `feboard-<n>/', allocated by scanning for the first free index, plus a
# `latest' symlink for convenience.  Nothing is ever deleted, and a stamp can
# only ever belong to the launch whose directory it is in.
i=1
while [ -e "$B/feboard-$i" ]; do i=$((i + 1)); done
OUT=$B/feboard-$i
mkdir -p "$OUT"
ln -sfn "$OUT" "$B/feboard-latest"
echo "== launch $i -> $OUT  (nothing from earlier launches is removed)"
# The per-target stamp mtcheck.sh writes is shared across launches, so clear it
# for each tool as that tool starts (below), never wholesale here.
for TOOL in "$@"; do
  echo "################################ $TOOL"
  rm -f "$B/check-$T.rc"
  MT_CHECK_TOOL=$TOOL MT_COMPILE_ONLY=1 \
    sh "$S/mtcheck.sh" "$B" "$T" > "$OUT/$TOOL.out" 2>&1
  rc=$?
  echo "$rc" > "$OUT/$TOOL.rc"
  echo "$TOOL rc=$rc"
  # Copy the artefacts under a per-tool name while they are still this run's.
  # ASSERT THE COPY, rather than let `[ -f ] && cp' fail silently: a tool that
  # ran and wrote nothing and a tool whose artefacts were not copied give the
  # same empty directory, and the figure is quoted from this copy.
  for f in sum log; do
    src="$B/gcc/testsuite.$T/$TOOL/$TOOL.$f"
    if [ -f "$src" ]; then
      cp "$src" "$OUT/$TOOL.$f"
    else
      echo "  NOTE: $TOOL produced no $TOOL.$f -- the suite wrote no $f."
      echo "        That is a NULL RESULT, not a pass; do not quote a figure."
    fi
  done
  tail -3 "$OUT/$TOOL.out"
done
echo "artefacts in $OUT (and $B/feboard-latest)"
