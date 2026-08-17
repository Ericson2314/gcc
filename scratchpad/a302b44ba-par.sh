#!/bin/sh
# a302b44ba-par.sh -- finish the in-flight DFP row by running the arms that the
# two SERIAL drivers have not reached yet, in PARALLEL, on their own trees.
#
# WHY THIS EXISTS.  The row left two detached drivers running, each a `for t in
# <4 targets>' loop with a single-threaded runtest inside it.  At ~1h20m per
# target that is ~6h per side, ~12h for the row, and the x86_64 arm of each was
# still the one running.  The remaining arms do not depend on each other, so
# they are started here instead of queued behind x86_64.
#
# THE STOCK SIDE IS FREE.  The four stock controls are FOUR SEPARATE BUILD
# DIRS, so aarch64 and s390x share nothing with the running x86_64 arm and can
# start immediately with no interference of any kind.
#
# THE MULTI-TARGET SIDE IS NOT, AND THAT IS THE WHOLE REASON FOR THE COPIES.
# `mtcheck.sh' does `rm -f site.exp' in $B/gcc and regenerates it per target,
# because site.exp does NOT depend on TEST_TARGET (gcc/Makefile.in) and a second
# `make check-gcc' would otherwise silently reuse the FIRST target's triple --
# a clean run attributed to the wrong target, which is the exact failure the
# harness's post-condition readback exists to catch.  Two concurrent mtcheck.sh
# in ONE build dir would race on precisely that file.  So each extra
# multi-target arm gets its OWN COPY of the build tree (1.4G, cheap) and the
# original is left entirely alone for the running x86_64 arm.
#
# THE COPY IS NOT ASSUMED SOUND, IT IS CHECKED.  A copied GCC build dir is only
# usable if the binaries are byte-identical and still resolve their own target;
# `cp -a' plus absolute paths baked into config.status is a real hazard.  So
# before any run is launched, this script requires md5 equality of `gcc/xgcc'
# and `gcc/cc1' against the original, and it REFUSES to launch if they differ.
# Beyond that the run is protected by mtcheck.sh's own guards, which are the
# arm that can FAIL here: the site.exp triple readback, the "compiler names the
# target back" check, and GUARD 3c's readlink -f identity of the assembler.
#
# NOT A REPLACEMENT FOR THE SERIAL DRIVERS.  They are deliberately NOT killed.
# When the original mtcheck.sh reaches aarch64 it will run it again in the
# original tree; that duplicate is a free REPLICATION arm -- two independently
# driven runs of the same target on the same bits -- not waste.  Compare them.
#
# usage: a302b44ba-par.sh
set -u
export LC_ALL=C
S=$(cd "$(dirname "$0")" && pwd)
ORIG=/tmp/b-302b44ba-mt
TOOLS=/tmp/tools-302b44ba/bin
LOGD=/tmp/par-302b44ba
mkdir -p "$LOGD"

# ---- stock side: aarch64 and s390x, straight away, own dirs already -------
for t in aarch64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  d=/tmp/b-stock-agent-302b44ba-$t
  [ -x "$d/gcc/xgcc" ] || { echo "FATAL: no stock xgcc for $t"; exit 9; }
  # IDEMPOTENT: this script had to be re-run once (the multi-target half
  # refused for a missing WANT_ANCHOR while the stock half had already
  # launched).  Re-launching a second sc-check on a build dir that already has
  # one running would have two runtests writing one gcc.sum.
  if pgrep -f "sc-check.sh $d" > /dev/null 2>&1; then
    echo "-- STOCK $t already running, not relaunching"
    continue
  fi
  echo "-- launching STOCK $t"
  setsid env MT_COMPILE_ONLY=1 SC_TOOLS="$TOOLS" \
    sh /tmp/agent-302b44ba/scratchpad/sc-check.sh "$d" "$t" \
    > "$LOGD/stock-$t.log" 2>&1 &
done

# ---- multi-target side: aarch64 and s390x, each on its own copy -----------
o_xgcc=$(md5sum "$ORIG/gcc/xgcc" | cut -d' ' -f1)
o_cc1=$(md5sum  "$ORIG/gcc/cc1"  | cut -d' ' -f1)
echo "-- original $ORIG  xgcc $o_xgcc  cc1 $o_cc1"

for t in aarch64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  C=/tmp/b-302b44ba-mt-$t
  if [ ! -x "$C/gcc/xgcc" ]; then
    echo "-- copying $ORIG -> $C"
    rm -rf "$C"
    cp -a "$ORIG" "$C" || { echo "FATAL: copy failed for $t"; exit 9; }
  fi
  c_xgcc=$(md5sum "$C/gcc/xgcc" | cut -d' ' -f1)
  c_cc1=$(md5sum  "$C/gcc/cc1"  | cut -d' ' -f1)
  if [ "$c_xgcc" != "$o_xgcc" ] || [ "$c_cc1" != "$o_cc1" ]; then
    echo "FATAL[$t]: copy is NOT the same compiler."
    echo "  xgcc $c_xgcc vs $o_xgcc"
    echo "  cc1  $c_cc1  vs $o_cc1"
    echo "  REFUSING to launch: a run on a different binary is not this row."
    exit 9
  fi
  echo "-- copy $C verified byte-identical (xgcc+cc1)"
  # The copy must carry its own asdir for this target or GUARD 3c cannot pass.
  [ -d "$C/asdir-$t" ] || { echo "FATAL[$t]: copy has no asdir-$t"; exit 9; }
  echo "-- launching MT $t on $C"
  # WANT_ANCHOR IS THE SNAPSHOT'S VALUE, NOT THE TIP'S.  This row's build was
  # made from /tmp/snap-multi-target-7b39423abba, where
  # `grep -c MULTI_TARGET gcc/Makefile.in' = 55.  At the branch tip it is 58
  # (`423c81b65f2' added three MULTI_TARGET_GEN_HDRS lines).  Passing 58 here
  # would make the guard refuse -- correctly, because 58 is not the compiler
  # that is under test.  The anchor is EXACT in both directions by design.
  setsid env MT_TAG=b-302b44ba MT_COMPILE_ONLY=1 WANT_ANCHOR=55 \
    "MT_TOOLS_$(echo "$t" | tr .- __)=$TOOLS" \
    sh "$S/mtcheck.sh" "$C" "$t" \
    > "$LOGD/mt-$t.log" 2>&1 &
done

wait
echo "PARDONE"
