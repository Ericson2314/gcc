#!/bin/sh
# a5764a65f9eec0063 -- run one .exp through mtcheck.sh and PRESERVE its
# gcc.sum/gcc.log under a run-specific name before anything can overwrite them.
#
# WHY THIS EXISTS.  `mtcheck.sh' writes every run to the same
# `testsuite.<triple>/gcc/gcc.sum'.  Launching a second run destroys the
# first's artefacts, and the destroyed file looks exactly like a present one --
# I read a `sme/acle-asm' log believing it was `sme2/acle-asm's and drew a
# wrong conclusion from it.  The `.rc' stamp says a run FINISHED; it does not
# say the file on disk still belongs to that run.
#
# Runs are therefore SEQUENTIAL here by construction, and the copies are taken
# before returning.
#
# usage: sh a5764a65f9eec0063-score.sh <builddir> <tag> <exp> [<exp> ...]
set -eu
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}; shift
TAG=${1:?tag}; shift
OUT=${OUT:-/tmp/w-a5764a65f9eec0063/scores}
T=aarch64-unknown-linux-gnu
mkdir -p "$OUT"

for exp in "$@"; do
  echo "########## $TAG / $exp"
  WANT_ANCHOR=52 \
  MT_TOOLS_aarch64_unknown_linux_gnu=/tmp/tools-a5764a65f9eec0063/bin \
  MT_COMPILE_ONLY=1 \
  MT_RUNTESTFLAGS="$exp" \
  sh "$S/mtcheck.sh" "$B" "$T" > "$OUT/$TAG-$exp.mtlog" 2>&1 || true

  rc=$(cat "$B/check-$T.rc" 2>/dev/null || echo missing)
  echo "  mtcheck rc stamp: $rc"
  [ "$rc" = 0 ] || { echo "  REFUSING to score: no rc=0 stamp"; continue; }

  src=$B/gcc/testsuite.$T/gcc
  cp "$src/gcc.sum" "$OUT/$TAG-$exp.sum"
  cp "$src/gcc.log" "$OUT/$TAG-$exp.log"
  # Non-vacuity: the preserved sum must actually contain results.
  n=$(grep -c '^\(PASS\|FAIL\)' "$OUT/$TAG-$exp.sum" || true)
  [ "$n" -gt 0 ] || { echo "  FATAL: preserved sum has no PASS/FAIL lines"; exit 9; }
  echo "  preserved $OUT/$TAG-$exp.sum  ($n result lines)"
  grep -A3 'TARGET  *PASS' "$OUT/$TAG-$exp.mtlog" | tail -1
done
