#!/bin/sh
# Run `gcc.target/<cpu>' on the four named targets in ONE build dir and
# PRESERVE each run's artefacts under a per-run name.
#
# THE PRESERVATION IS THE POINT, NOT TIDINESS.  `mtcheck.sh' writes every run
# to the same `testsuite.<triple>/gcc/gcc.sum', and INSTRUMENTS.md records a
# session lost to reading one `.exp''s log believing it was another's: a
# destroyed artefact looks exactly like a present one, and the `.rc' stamp
# says a run FINISHED, not that the file still belongs to it.  Each `.sum' is
# copied out here before the next target starts.
#
# `gcc.target/<cpu>' ONLY -- the subset the 28-back-end board used, and the
# one where `scan-assembler' divergence lives.  Say so when quoting: this is
# not `make check-gcc'.
#
# usage: OUT=<dir> a98009045f7229938-suite.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
OUT=${OUT:?output dir}
TOOLS=${TOOLS:?dir holding <triple>-as for every target below}
mkdir -p "$OUT"
WANT_ANCHOR=$(grep -c MULTI_TARGET "$(cat "$B/MY-SRC")/gcc/Makefile.in")
export WANT_ANCHOR

for row in i386:x86_64-pc-linux-gnu s390:s390x-ibm-linux-gnu \
           aarch64:aarch64-unknown-linux-gnu riscv:riscv64-unknown-linux-gnu; do
  be=${row%%:*}; T=${row#*:}
  echo "=== $T ($be.exp)  $(date +%H:%M:%S)"
  # The stamp is removed BEFORE the run, not after: a culled run leaves a
  # stale `.rc' beside a PARTIAL `.sum', and the copy below would then be
  # authorised by the PREVIOUS run's success.  `fixboard.sh' does the same.
  rm -f "$B/check-$T.rc"
  # THE PER-TARGET TOOLS VARIABLE IS REQUIRED BY mtcheck's OWN GUARD, and the
  # guard is right: without this target's binutils the driver resolves `as' to
  # a shim around the HOST assembler and every assemble-shaped test fails for
  # a reason that is not the compiler (~10,000 results per target, on record).
  # The variable name is the triple with `-' and `.' turned into `_'.
  V=MT_TOOLS_$(echo "$T" | tr '.-' '__')
  [ -x "$TOOLS/$T-as" ] || { echo "FATAL: no $TOOLS/$T-as; refusing rather
than letting the host assembler stand in for this target."; exit 9; }
  MT_COMPILE_ONLY=1 MT_SUITE_JOBS=${MT_SUITE_JOBS:-6} \
    MT_RUNTESTFLAGS="$be.exp" \
    env "$V=$TOOLS" \
    sh "$S/mtcheck.sh" "$B" "$T" > "$OUT/run-$T.out" 2>&1
  rc=$?
  echo "  mtcheck rc=$rc"
  SUM="$B/gcc/testsuite.$T/gcc/gcc.sum"
  if [ -f "$SUM" ]; then
    cp "$SUM" "$OUT/gcc-$T.sum"
    cp "$B/gcc/testsuite.$T/gcc/gcc.log" "$OUT/gcc-$T.log" 2>/dev/null
    echo "  preserved $(grep -c '^PASS:' "$OUT/gcc-$T.sum") PASS / \
$(grep -c '^FAIL:' "$OUT/gcc-$T.sum") FAIL"
  else
    # An absent .sum is NOT an empty result set; it means the run did not
    # produce one, which is a different fact and is recorded as one.
    echo "  NO .sum -- the run produced no artefact (NOT 'zero results')"
  fi
done
echo "=== done $(date +%H:%M:%S)"
