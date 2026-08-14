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

VER=$(cat "$B/gcc/BASE-VER")
printf '%-30s %8s %8s %8s %8s %8s %8s %8s\n' \
  TARGET PASS FAIL XPASS XFAIL UNSUP UNRES ERROR
printf '%s\n' "--------------------------------------------------------------------------------------------"

any=0
for T in "$@"; do
  TSD="$B/gcc/testsuite.$T"
  if [ ! -f "$B/check-$T.rc" ]; then
    printf '%-30s %s\n' "$T" "REFUSED: no check-$T.rc stamp -- the run did not finish"
    continue
  fi
  SUM=$(find "$TSD" -name 'gcc.sum' 2>/dev/null | head -1)
  if [ -z "$SUM" ]; then
    printf '%-30s %s\n' "$T" "REFUSED: no gcc.sum under $TSD"
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
  e=$(grep -c '^ERROR: '       "$SUM" || true)
  tot=$((p+f+xp+xf+u+ur+e))
  if [ "$tot" -eq 0 ]; then
    printf '%-30s %s\n' "$T" "REFUSED: 0 results scored -- a board of zeroes is not a clean sweep"
    continue
  fi
  any=1
  printf '%-30s %8s %8s %8s %8s %8s %8s %8s\n' "$T" "$p" "$f" "$xp" "$xf" "$u" "$ur" "$e"
done

if [ "$any" = 0 ]; then
  echo
  echo "FATAL: no target produced a scoreable run.  Refusing to report a board."
  exit 9
fi

echo
echo "== top FAIL causes per target (first 12, by test file)"
for T in "$@"; do
  SUM=$(find "$B/gcc/testsuite.$T" -name 'gcc.sum' 2>/dev/null | head -1)
  [ -n "$SUM" ] || continue
  echo "-- $T"
  grep '^FAIL: ' "$SUM" | awk '{print $2}' | sort | uniq -c | sort -rn | head -12
done
