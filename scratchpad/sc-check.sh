#!/bin/sh
# STOCK CONTROL, part D -- run the SAME testsuite the multi-target board runs,
# against the stock cross compiler.
#
# This is `mtcheck.sh' with the multi-target-only guards removed and NOTHING
# else changed.  What is dropped and why, so the difference is auditable:
#
#   * GUARD 1 (specs-config exists) and GUARD 2 (cc1 names the target back
#     through -ftarget-config=) have no stock analogue -- there is no config
#     file and no flag.  GUARD 2's PURPOSE survives, as guard S2 below:
#     the compiler must still name the target back, read out of the RUNNING
#     driver (-dumpmachine), never out of the build dir's name.
#   * GUARD 3 (a bare xgcc must REFUSE to compile without the flag) is
#     inverted, because a stock cross xgcc obviously compiles without a flag.
#     Its purpose -- prove the target selection is doing something -- is
#     served here by S2 instead.
#
# Everything else is identical BY CONSTRUCTION and each of these matters:
#   * `rm -f site.exp' before each run (site.exp does not depend on the target).
#   * TESTSUITEDIR=testsuite.<T>, so the scorer finds the same paths.
#   * The `.rc' stamp is CLEARED before the run and written after make returns.
#   * MT_TARGET_NAME / MT_COMPILE_ONLY exported into runtest's environment.
#   * GUARD 4/G5: the `MULTI-TARGET RUN' banner must appear in the MERGED log.
#     On this side that arm is doing MORE work than on the other, because
#     upstream has no multi-target.exp at all -- if the graft in sc-snap.sh had
#     failed, MT_COMPILE_ONLY would be silently inert, every `dg-do run' test
#     would LINK against a libgcc that does not exist, and the control would
#     carry a uniform link-FAIL floor that reads as "stock is worse".  That is
#     the single most likely way this whole comparison could be wrong, and it
#     is the only one that is completely silent.  Hence it is also asserted a
#     second way: the compile-only banner specifically, not just the target
#     banner.
#   * The site.exp post-condition (every site.exp attributes to <T>).
#
# usage: sc-check.sh <builddir> <triple>
#   MT_RUNTESTFLAGS, MT_COMPILE_ONLY, MT_MAKEFLAGS as in mtcheck.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
T=${2:?target triple}

# DERIVED, NOT HARDCODED -- see sc-conf.sh for why this one line mattered.
# SC_TAG is the explicit override for reading a stock build dir an earlier
# worktree produced; the fallback when the path is not a worktree is a REFUSAL.
_wt=$(basename "$(cd "$S/.." && pwd)")
case "$_wt" in
  agent-*) ;;
  *) echo "FATAL: $S is not a .../worktrees/agent-<hash>/scratchpad checkout;"
     echo "  REFUSING rather than accepting any build dir.  Set SC_TAG=."; exit 9 ;;
esac
SC_TAG=${SC_TAG:-b-stock-$_wt}
case "$B" in
  *"$SC_TAG"*) ;;
  *) echo "FATAL: $B is not this worktree's stock build dir (expected *$SC_TAG*)"; exit 9 ;;
esac
[ -f "$B/MY-SRC" ] || { echo "FATAL: $B has no MY-SRC"; exit 9; }
SRC=$(cat "$B/MY-SRC")
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = 0 ] || { echo "FATAL: srcdir $SRC anchor=$n; the control must be stock"; exit 9; }
[ -f "$SRC/STOCK-SHA" ] || { echo "FATAL: $SRC is not an sc-snap.sh snapshot"; exit 9; }
[ ! -w "$SRC/gcc/Makefile.in" ] || { echo "FATAL: $SRC is writable; not an immutable snapshot"; exit 9; }
[ -f "$B/build.rc" ] || { echo "FATAL: no $B/build.rc -- the build did not finish"; exit 9; }
[ "$(cat "$B/build.rc")" = 0 ] || { echo "FATAL: build.rc=$(cat "$B/build.rc")"; exit 9; }
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
[ -x "$B/gcc/cc1" ]  || { echo "FATAL: no $B/gcc/cc1"; exit 9; }
# G5 at the source: the graft must still be there.
grep -q '^load_lib multi-target.exp$' "$SRC/gcc/testsuite/lib/gcc-dg.exp" \
  || { echo "FATAL: $SRC does not load multi-target.exp; compile-only would be inert"; exit 9; }

RTF=${MT_RUNTESTFLAGS:-}
echo "== sc-check: STOCK srcdir $SRC sha=$(cat "$SRC/STOCK-SHA") anchor=$n"
echo "== target: $T   runtestflags: [$RTF]   compile-only: [${MT_COMPILE_ONLY:-}]"

# ---- S2: the RUNNING compiler must name the target back ----
got=$("$B/gcc/xgcc" -B"$B/gcc/" -dumpmachine 2>"$B/probe-$T.err")
if [ "$got" != "$T" ]; then
  echo "FATAL[$T]: the compiler reports its target as '$got', not '$T'"
  sed -n '1,5p' "$B/probe-$T.err"
  exit 9
fi
echo "-- guard S2: xgcc -dumpmachine = $T"

# ---- S3: THE TARGET'S SYSTEM HEADERS MUST ACTUALLY BE REACHABLE ----
# The multi-target side reads `native_system_header_dir' out of specs-config at
# run time and finds them.  The control has to reach the SAME directory or the
# comparison is between two different header environments -- which it was, at
# 66,883 `stdint.h: No such file' diagnostics, producing a FAIL column within
# 0.1% of the multi-target board's for an entirely unrelated reason.  A control
# with its own floor is not a control.  Both halves asserted: the directory is
# in the search list, AND a translation unit including <stdint.h> compiles.
HDRDIR=$(cat "$B/TARGET-HDR") || { echo "FATAL: no $B/TARGET-HDR"; exit 9; }
echo '#include <stdint.h>
int64_t sc_probe;' > "$B/hdr-probe-$T.c"
if ! "$B/gcc/xgcc" -B"$B/gcc/" -S -o "$B/hdr-probe-$T.s" "$B/hdr-probe-$T.c" \
       > "$B/hdr-probe-$T.err" 2>&1; then
  echo "FATAL[$T]: the stock compiler cannot find its own target system headers."
  sed -n '1,10p' "$B/hdr-probe-$T.err"
  exit 9
fi
"$B/gcc/xgcc" -B"$B/gcc/" -E -v -o /dev/null "$B/hdr-probe-$T.c" 2> "$B/hdr-list-$T.txt"
grep -q "^ $HDRDIR\$" "$B/hdr-list-$T.txt" \
  || { echo "FATAL[$T]: $HDRDIR is not in the include search list:";
       sed -n '/search starts here/,/End of search/p' "$B/hdr-list-$T.txt"; exit 9; }
echo "-- guard S3: target system headers reachable at $HDRDIR"

# ---- S4: THE ASSEMBLER MUST BE THE TARGET'S, NOT THE HOST'S ----
# Read out of the RUNNING driver (-print-prog-name=as), not out of the
# Makefile: a `gcc/as' wrapper in the build dir answers to the name `as' while
# executing something else entirely, which is exactly what happened.  Then
# assemble a real object and make `readelf -h' name the machine, because "a
# tool accepted it" is not "the tool was the right tool" -- PRINCIPLES, and
# also because the host x86 gas ACCEPTS an empty file.
ASPROG=$("$B/gcc/xgcc" -B"$B/gcc/" -print-prog-name=as)
echo "-- assembler in use: $ASPROG"
printf 'int sc_as_probe (int x) { return x + 1; }\n' > "$B/as-probe-$T.c"
"$B/gcc/xgcc" -B"$B/gcc/" -c -o "$B/as-probe-$T.o" "$B/as-probe-$T.c" \
  > "$B/as-probe-$T.err" 2>&1 \
  || { echo "FATAL[$T]: the control cannot assemble a one-line function:";
       sed -n '1,10p' "$B/as-probe-$T.err"; exit 9; }
TOOLS=$(cat "$B/TARGET-TOOLS" 2>/dev/null || echo /tmp/tools-agent-a3464debf6893de84/bin)
[ -x "$TOOLS/$T-readelf" ] || { echo "FATAL: no $TOOLS/$T-readelf"; exit 9; }
mach=$("$TOOLS/$T-readelf" -h "$B/as-probe-$T.o" \
        | sed -n 's/^ *Machine: *//p')
# THE EXPECTED MACHINE IS NAMED PER TARGET AND THE DEFAULT ARM IS A REFUSAL.
# An `x86_64' arm is NOT a formality here: it is the one target for which the
# HOST assembler produces the RIGHT answer, so a mis-resolved `as' is invisible
# on this row and on no other -- which is exactly the reason the whole
# host-assembler defect went unnoticed for the life of the project.  The arm
# still earns its place because it is the difference between "the machine was
# checked and is x86-64" and "the machine was never checked".
case "$T:$mach" in
  aarch64*:*AArch64*) ;;
  s390x*:*S/390*|s390x*:*IBM*) ;;
  riscv64*:*RISC-V*) ;;
  x86_64*:*X86-64*|x86_64*:*x86-64*) ;;
  *) echo "FATAL[$T]: the control assembled to machine '$mach' -- wrong target."
     echo "  (ORIGINAL_AS_FOR_TARGET pointing at the host assembler produces"
     echo "   exactly this, and it is silent until something looks.)"
     exit 9 ;;
esac
echo "-- guard S4: assembled object reports Machine: $mach"

TSD="testsuite.$T"
rm -f "$B/gcc/site.exp"
rm -rf "$B/gcc/$TSD"
rm -f "$B/check-$T.rc"

# THE ADDRESS-SPACE CAP, THE SAME ONE mtcheck.sh PUTS ON THE SUBJECT SIDE.
#
# It was NOT here when the aarch64 and s390x controls were taken, and those two
# runs recorded KILLED 0, so it changed nothing for them.  It is added because
# the riscv64 control is new and riscv64 is the target that took cc1 to 20.8 GB
# on `gcc.target/riscv/pr117506.c' -- an uncapped control run can take the box,
# and a control that dies is worse than a slow one.
#
# `-v', never `-m': Linux does not enforce RLIMIT_RSS, so `-m' is accepted and
# does nothing -- the mitigation-that-cannot-fire shape.  Read back
# immediately, and REFUSE if it did not take: a silently absent cap is the one
# outcome that must not be possible.  Anything it kills is counted as KILLED by
# the scorer and is never subtracted from any column.
CAP=${MT_MEMCAP_KB:-8388608}
( ulimit -v "$CAP" || exit 9
  [ "$(ulimit -v)" = "$CAP" ] || { echo "FATAL: ulimit -v $CAP did not take"; exit 9; }
  sh "$S/eb-shell-dj.sh" "cd $B/gcc && \
    PATH=$TOOLS:\$PATH \
    MT_TARGET_NAME=$T \
    MT_COMPILE_ONLY='${MT_COMPILE_ONLY:-}' \
    export MT_TARGET_NAME MT_COMPILE_ONLY PATH; \
    make ${MT_MAKEFLAGS:-} check-gcc \
      TESTSUITEDIR=$TSD \
      RUNTESTFLAGS=\"GCC_UNDER_TEST='$B/gcc/xgcc -B$B/gcc/' $RTF\"" \
) > "$B/check-$T.out" 2> "$B/check-$T.err"
rc=$?
echo "$rc" > "$B/check-$T.rc"
echo "-- make check-gcc rc=$rc"

nse=0; bad=0
for SE in $(find "$B/gcc/$TSD" -name site.exp); do
  nse=$((nse+1))
  saw=$(sed -n 's/^set target_triplet //p' "$SE" | head -1)
  [ "$saw" = "$T" ] || { echo "FATAL[$T]: $SE says target_triplet=$saw"; bad=$((bad+1)); }
done
[ "$bad" = 0 ] || exit 9
[ "$nse" -gt 0 ] || { echo "FATAL[$T]: no site.exp under $B/gcc/$TSD -- the run did not happen"; exit 9; }
echo "-- guard: all $nse site.exp files attribute to $T"

LOG="$B/gcc/$TSD/gcc/gcc.log"
grep -q "MULTI-TARGET RUN: target = $T" "$LOG" 2>/dev/null || {
  echo "FATAL[$T]: gcc.log carries no 'MULTI-TARGET RUN: target = $T' banner."
  echo "  the grafted multi-target.exp was INERT on the stock side."
  exit 9; }
echo "-- guard G5a: multi-target.exp banner present"
if [ -n "${MT_COMPILE_ONLY:-}" ]; then
  grep -q "MULTI-TARGET RUN: compile-only" "$LOG" || {
    echo "FATAL[$T]: MT_COMPILE_ONLY was set but the dg-do downgrade did NOT install."
    echo "  every dg-do run test would have LINKED against an absent libgcc,"
    echo "  giving the control a link-FAIL floor the multi-target board has not."
    exit 9; }
  echo "-- guard G5b: dg-do run/link/assemble downgrade IS installed"
fi
echo
sh "${MT_SCORER:-$S/taa-mtscore.sh}" "$B" "$T"
