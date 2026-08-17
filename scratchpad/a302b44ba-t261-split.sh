#!/bin/sh
# TASK 261 ACCEPTANCE: THE PER-OWNER HEADER SPLIT.
#
# The nine generated headers libgcc opens now come from FOUR producers, split by
# who OWNS each file rather than by who consumes it:
#
#   target-specs   <target>/include/tm.h, tm-<triple>.h        per triple
#   gcc install    <target>/include/{options,insn-*}-<base>.h  per back end
#                  + the three plain-name shims
#   gcc install    gen-headers/{auto-host.h,version.h}         ONCE
#   libgcc         tconfig.h, in libgcc's own build dir        per library build
#
# FOUR ARMS, each able to fail:
#
#   1 COMPLETENESS.  The union supplies all NINE.  Asserted separately from
#     disjointness because a split that DROPS one passes an overlap check and
#     breaks the build -- which is the failure mode a "producers don't collide"
#     test is blind to.
#   2 DISJOINTNESS, at FILE granularity.  Two producers writing one path is a
#     defect even when the bytes agree; it is what stopped `gcc-composed'.
#   3 TWO BACK ENDS build standalone, compared on NAMED OBJECTS rather than exit
#     status -- both stop later on this environment's missing target C library,
#     so a status comparison would report that instead and show nothing.
#   4 `_gcov_merge_add.o' IN PARTICULAR, because that is the object that caught
#     the version.h error (#268 arm A) and it is the only one whose absence
#     proved a header was missing.
#
# usage: PREFIX=<install> AA=<aarch64 libgcc build> AR=<armv6l libgcc build> \
#        a302b44ba-t261-split.sh
set -u
P=${PREFIX:?install prefix}
AA=${AA:?aarch64 libgcc build dir}
AR=${AR:?armv6l libgcc build dir}
T1=aarch64-unknown-linux-musl
T2=armv6l-unknown-linux-gnueabihf
V=$(ls "$P/lib/gcc" | head -1)
I=$P/lib/gcc/$V
bad=0
note () { printf '  %-58s %s\n' "$1" "$2"; }

for pair in "$T1:aarch64:$AA" "$T2:arm:$AR"; do
  t=${pair%%:*}; rest=${pair#*:}; cpu=${rest%%:*}; B=${rest##*:}
  echo "== $t (base $cpu)"
  d=$I/$t/include

  # ARM 1: COMPLETENESS.  Every one of the nine, wherever it lives.
  miss=
  for f in tm.h tm-$(echo "$t"|sed 's/[^A-Za-z0-9_]/_/g').h \
           options-$cpu.h insn-modes-$cpu.h insn-constants-$cpu.h \
           options.h insn-constants.h insn-modes.h; do
    [ -f "$d/$f" ] || miss="$miss $f"
  done
  for f in auto-host.h version.h; do [ -f "$I/gen-headers/$f" ] || miss="$miss gen-headers/$f"; done
  [ -f "$B/tconfig.h" ] || miss="$miss tconfig.h(libgcc)"
  if [ -z "$miss" ]; then note "arm 1  all nine present across the union" "OK"
  else note "arm 1  MISSING FROM THE UNION:$miss" "*** FAIL"; bad=1; fi

  # ARM 2: DISJOINTNESS.  target-specs owns exactly tm.h + tm-<key>.h in $d;
  # everything else there is gcc's; gen-headers is gcc's alone; tconfig.h is
  # libgcc's and must NOT have been installed by gcc anywhere.
  if [ -f "$d/tconfig.h" ]; then
    note "arm 2  gcc still installs tconfig.h into $t" "*** FAIL"; bad=1
  else note "arm 2  tconfig.h is libgcc's alone (not in the install)" "OK"; fi
  for f in auto-host.h version.h; do
    if [ -f "$d/$f" ]; then note "arm 2  $f still copied per target" "*** FAIL"; bad=1; fi
  done
  [ -f "$d/auto-host.h" ] || [ -f "$d/version.h" ] || \
    note "arm 2  auto-host.h/version.h live once, not per target" "OK"

  # ARM 3/4: NAMED OBJECTS.
  n=$(ls "$B"/*.o 2>/dev/null | wc -l)
  if [ -f "$B/_gcov_merge_add.o" ]; then
    note "arm 3/4  $n objects; _gcov_merge_add.o $(wc -c < "$B/_gcov_merge_add.o") bytes" "OK"
  else
    note "arm 3/4  $n objects; _gcov_merge_add.o ABSENT" "*** FAIL"; bad=1
  fi
  # No object may be missing because one of the nine was: that is the specific
  # failure this split could introduce, and it names itself in the log.
  if [ -n "${LOGDIR:-}" ] && [ -f "$LOGDIR/$(basename "$B").log" ]; then
    h=$(grep -cE "(tm|tconfig|auto-host|version|options|insn-modes|insn-constants)\.h: No such file" \
          "$LOGDIR/$(basename "$B").log")
    [ "$h" = 0 ] && note "arm 3  no missing-header errors among the nine" "OK" \
                 || { note "arm 3  $h missing-header errors among the nine" "*** FAIL"; bad=1; }
  fi
done

# NON-VACUITY ACROSS THE PAIR: the two back ends must not have produced the same
# object, or the whole run could be one target measured twice.
if [ -f "$AA/_gcov_merge_add.o" ] && [ -f "$AR/_gcov_merge_add.o" ]; then
  if cmp -s "$AA/_gcov_merge_add.o" "$AR/_gcov_merge_add.o"; then
    echo "*** FAIL: the two back ends produced an identical _gcov_merge_add.o"; bad=1
  else
    echo "-- the two back ends' _gcov_merge_add.o differ ($(wc -c < "$AA/_gcov_merge_add.o") vs $(wc -c < "$AR/_gcov_merge_add.o") bytes), as they must"
  fi
fi
[ "$bad" = 0 ] && echo "ALL ARMS PASS" || echo "SOME ARM FAILED"
exit $bad
