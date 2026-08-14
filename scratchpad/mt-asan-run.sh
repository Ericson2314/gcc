#!/bin/sh
# mt-asan-run.sh -- run an ASAN+UBSan `cc1' for one target, N times, and report
# what AddressSanitizer said.
#
# THE OPTION THAT DECIDES WHETHER THIS INSTRUMENT WORKS AT ALL:
#
#     handle_segv=2:allow_user_segv_handler=0
#
# `toplev.cc:329' installs GCC's own SIGSEGV handler.  Without this, a
# heap-buffer-overflow that faults is caught by GCC, ASAN never prints, and the
# log is EMPTY beside a crashing cc1 -- indistinguishable from a clean run.
# A clean-looking log without this option is a NULL RESULT, not a pass, so the
# script refuses to score unless it can show the option was in force.
#
# detect_leaks=0 is carried too: it is needed to BUILD (GCC's generators leak by
# design and LSan makes genhooks/genmodes/gengtype exit 23), and leaving it on
# for the run would bury the overflow report under a leak report from cc1's own
# arena, which is not the question.
#
# N RUNS AND NOT ONE.  PRINCIPLES section 4: ia64 gave five distinct outcomes in
# eight runs before this was looked at, and a single run fails towards the
# green.  The verdict is over all N.
#
# usage: mt-asan-run.sh <builddir> <canonical-triple> <input.c> [-O2] [runs]
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}; T=${2:?canonical triple}; IN=${3:?input .c}; OPT=${4:--O2}; N=${5:-6}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"
case "$IN" in /*) ;; *) mt_die "IN must be ABSOLUTE (a relative path has produced a false green here)" ;; esac
[ -s "$IN" ] || mt_die "$IN is absent or empty"
[ -x "$D/gcc/cc1" ] || mt_die "$D/gcc/cc1 is absent"

# THE cc1 UNDER TEST MUST ACTUALLY BE INSTRUMENTED.  A non-ASAN cc1 produces a
# clean log for the best possible reason and the worst possible one at once.
if ! grep -aq '__asan_report_store' "$D/gcc/cc1"; then
  mt_die "$D/gcc/cc1 carries no __asan_* symbols -- it is not an ASAN build,
  so an empty report would prove nothing"
fi
echo "cc1 is ASAN-instrumented (__asan_report_store present)"

CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] || mt_die "no specs-config for $T under $D/lib/gcc/*/$T/ -- run the
  target-specs probe for it first (mt-asan-specs.sh)"
[ -s "$CFG" ] || mt_die "$CFG is empty"

O=$D/asan-$T; rm -rf "$O"; mkdir -p "$O"
export ASAN_OPTIONS="detect_leaks=0:handle_segv=2:allow_user_segv_handler=0:abort_on_error=0"
echo "ASAN_OPTIONS=$ASAN_OPTIONS"

i=0
while [ "$i" -lt "$N" ]; do
  i=$((i+1))
  ( cd "$D/gcc" && timeout 600s ./cc1 -quiet -nostdinc "$OPT" \
      -ftarget-config="$CFG" "$IN" -o "$O/$i.s" ) > "$O/$i.out" 2> "$O/$i.err"
  echo "rc=$?" > "$O/$i.rc"
done

echo "== $T $OPT, $N runs"
nover=0
for i in $(seq 1 "$N"); do
  rc=$(cat "$O/$i.rc")
  n=$(grep -c 'ERROR: AddressSanitizer' "$O/$i.err")
  u=$(grep -c 'runtime error:' "$O/$i.err")
  k=$(grep -m1 -o 'AddressSanitizer: [a-z-]*' "$O/$i.err")
  md5=$(md5sum < "$O/$i.s" 2>/dev/null | cut -c1-12)
  printf '  run %-2s %-6s asan=%s ubsan=%s %-40s md5=%s bytes=%s\n' \
    "$i" "$rc" "$n" "$u" "${k:--}" "$md5" "$(wc -c < "$O/$i.s" 2>/dev/null)"
  [ "$n" = 0 ] || nover=$((nover+1))
done
echo "== ASAN reports in $N runs: $nover"
if [ "$nover" -gt 0 ]; then
  echo "== first report, first 25 lines"
  for i in $(seq 1 "$N"); do
    if grep -q 'ERROR: AddressSanitizer' "$O/$i.err"; then
      sed -n '/ERROR: AddressSanitizer/,+24p' "$O/$i.err"
      break
    fi
  done
  exit 1
fi
echo "NO ASAN REPORT in $N runs (with handle_segv=2, so an empty log is a real
empty log and not GCC's own handler swallowing the fault)"
exit 0
