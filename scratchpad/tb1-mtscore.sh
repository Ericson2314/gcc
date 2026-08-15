#!/bin/sh
# mtscore.sh -- the BASELINE BOARD: target x (run, pass, fail, unsupported...).
#
# usage: mtscore.sh <builddir> <triple> [<triple> ...]
#
# THREE REFUSALS, because on this branch "the tests did not run" and "the tests
# passed" have repeatedly been the same silence:
#
#   * no `.rc' stamp        -> the run never finished; REFUSE, do not score a
#                              truncated .sum as a smaller number.
#   * no `=== gcc Summary' -> runtest died partway; a .sum without its summary
#                              is non-empty, greps clean, and is not a result.
#   * zero tests scored     -> non-vacuity.  An all-empty read is
#                              indistinguishable from "everything unsupported",
#                              and the harness must refuse rather than print a
#                              board of zeroes that reads as a clean sweep.
#
# NO FAILURE FLOOR IS SUBTRACTED ANYWHERE.  A constant floor deleted the signal
# on this branch once and hid 1447 real regressions.  UNRESOLVED is printed as
# its own column and never folded into anything: ~800 execution tests were
# silently UNRESOLVED here for months without moving a number.
set -u
B=${1:?build dir}; shift

# KILLED IS ITS OWN VERDICT AND IS NOT A TEST RESULT AT ALL.
#
# DejaGnu cannot tell "the compiler said no" from "the compiler was killed":
# an OOM-killed cc1 records as a plain FAIL.  A baseline is the thing every
# later change is scored against and nobody re-derives one once it exists, so
# machine load silently becomes permanent expected-failure noise -- real
# regressions then look like noise and noise looks like regression.  Counted
# from the LOG (the .sum cannot carry it) and printed BESIDE the board, never
# subtracted from FAIL: subtracting it would be a failure floor, and the point
# is to make the contamination visible, not to net it out.
printf '%-30s %8s %8s %8s %8s %8s %8s %8s %8s %8s\n' \
  TARGET PASS FAIL XPASS XFAIL UNSUP UNRES ERRUNQ ERRTCL ERRLIN
printf '%s\n' "----------------------------------------------------------------------------------------------------------------"

any=0
for T in "$@"; do
  TSD="$B/gcc/testsuite.$T"
  if [ ! -f "$B/check-$T.rc" ]; then
    printf '%-30s %s\n' "$T" "REFUSED: no check-$T.rc stamp -- the run did not finish"
    continue
  fi
  # THE MERGED SUM, BY EXACT PATH.  Under -j, make runs up to 128 runtest
  # slots into $TSD/gcc<N>/ and merges them with dg-extract-results.sh into
  # $TSD/gcc/gcc.sum.  A `find -name gcc.sum | head -1' therefore picks an
  # ARBITRARY SLOT -- one 128th of the suite -- and prints it as the board.
  # It did: a 13/6/3 slot was reported as a full aarch64 run.  Name the file.
  SUM="$TSD/gcc/gcc.sum"
  if [ ! -f "$SUM" ]; then
    printf '%-30s %s\n' "$T" "REFUSED: no merged $SUM"
    continue
  fi
  if ! grep -q '=== gcc Summary' "$SUM"; then
    printf '%-30s %s\n' "$T" "REFUSED: $SUM has no '=== gcc Summary' -- truncated run"
    continue
  fi
  p=$(grep -c '^PASS: '        "$SUM" || true)
  f=$(grep -c '^FAIL: '        "$SUM" || true)
  xp=$(grep -c '^XPASS: '      "$SUM" || true)
  xf=$(grep -c '^XFAIL: '      "$SUM" || true)
  u=$(grep -c '^UNSUPPORTED: ' "$SUM" || true)
  ur=$(grep -c '^UNRESOLVED: ' "$SUM" || true)
  # ERROR COUNTED LINES, NOT FAILURES.  One aborted `.exp' emits THREE
  # `^ERROR: ' lines and GCC's parallel harness repeats the block once per
  # runtest slot, so the column SCALED WITH `-j'.  Ported verbatim from
  # mtscore.sh, which is the live scorer.
  errlin=$(grep -c '^ERROR: ' "$SUM" || true)
  e=$(grep '^ERROR: ' "$SUM" | sed 's/[0-9][0-9]*/N/g' | sort -u | wc -l)
  errtcl=$(sed -n 's/^ERROR: tcl error sourcing \(.*\)\.$/\1/p' "$SUM" | sort -u | wc -l)
  # A harness error is not a test result and must not certify the run.
  tot=$((p+f+xp+xf+u+ur))
  if [ "$tot" -eq 0 ]; then
    printf '%-30s %s\n' "$T" "REFUSED: 0 results scored -- a board of zeroes is not a clean sweep"
    continue
  fi
  any=1
  printf '%-30s %8s %8s %8s %8s %8s %8s %8s %8s %8s\n' "$T" "$p" "$f" "$xp" "$xf" "$u" "$ur" "$e" "$errtcl" "$errlin"
done

if [ "$any" = 0 ]; then
  echo
  echo "FATAL: no target produced a scoreable run.  Refusing to report a board."
  exit 9
fi

echo
echo "== KILLED (compiler killed, NOT a test result -- machine contamination)"
KILLPAT='internal compiler error: Killed|terminated by signal 9|out of memory|virtual memory exhausted'
for T in "$@"; do
  LOG="$B/gcc/testsuite.$T/gcc/gcc.log"
  if [ ! -f "$LOG" ]; then
    printf '  %-28s %s\n' "$T" "no log"
    continue
  fi
  k=$(grep -c -iE "$KILLPAT" "$LOG" || true)
  printf '  %-28s %s\n' "$T" "$k"
  if [ "$k" -gt 0 ]; then
    grep -iE "$KILLPAT" "$LOG" | sed 's/^/      /' | head -10
  fi
done
echo "  load at scoring time: $(uptime | sed 's/.*load average/load average/')"
echo "  (a run taken above ~25 is PROVISIONAL -- say so wherever the board is quoted)"

echo
# WHAT MT_COMPILE_ONLY DOES NOT COVER, COUNTED RATHER THAN ASSUMED.
#
# The downgrade is implemented by wrapping `dg-do', so it reaches exactly the
# tests that declare their action through dg-do.  Anything that drives the
# compiler itself -- gcov.exp, the lto and compat suites, gcc.misc-tests --
# still LINKS and still EXECUTES, in a build with no target libgcc, and those
# failures are a floor: they are near-identical on every target and say
# nothing about back-end selection.  T173 read as "940 FAILs in gcov-19.c" on
# BOTH targets for this reason.
#
# Printed as its own line and NEVER subtracted (PRINCIPLES: a failure floor
# once hid 1447 real regressions here).  It is stated so the reader can see
# how much of the FAIL column is not a multi-target observation at all.
echo "== NOT DOWNGRADED (drove the compiler outside dg-do: linked and/or ran)"
for T in "$@"; do
  SUM="$B/gcc/testsuite.$T/gcc/gcc.sum"
  [ -f "$SUM" ] || continue
  ex=$(grep -cE '^(FAIL|PASS|UNRESOLVED|ERROR): .*(execution test|\(execute\)| execute )' "$SUM" || true)
  gv=$(grep -cE '^(FAIL|PASS): gcc\.misc-tests/gcov' "$SUM" || true)
  printf '  %-28s execution-shaped %-8s gcov %s\n' "$T" "$ex" "$gv"
done

echo
echo "== top FAIL causes per target (first 12, by test file)"
for T in "$@"; do
  SUM="$B/gcc/testsuite.$T/gcc/gcc.sum"
  [ -f "$SUM" ] || continue
  echo "-- $T"
  grep '^FAIL: ' "$SUM" | awk '{print $2}' | sort | uniq -c | sort -rn | head -12
done
