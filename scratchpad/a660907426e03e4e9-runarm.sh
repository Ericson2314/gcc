#!/bin/sh
# Detached driver for the arm ROW: specs, bars, then the two full suite runs.
#
# The order matters and is not cosmetic.  mt-specsread.sh is a PRECONDITION on
# mtcheck.sh (GUARD 3b), and mt-specs must have run before that; the bars are
# taken before the suites so that a bar that moved is known BEFORE eight hours
# of scoring rather than after.  One detached process, per INSTRUMENTS.md.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=/tmp/b-a660907426e03e4e9
SB=/tmp/b-stock-agent-a660907426e03e4e9-arm
TOOLS=/tmp/tools-agent-a660907426e03e4e9
TA=arm-unknown-linux-gnueabihf

set -e
[ "$(cat "$B/all-gcc.rc")" = 0 ]  || { echo "FATAL: mt build.rc != 0"; exit 9; }
[ "$(cat "$SB/build.rc")" = 0 ]   || { echo "FATAL: stock build.rc != 0"; exit 9; }

if [ -z "${SKIP_SPECS:-}" ]; then
echo "######## specs"
B=$B TOOLS=$TOOLS sh "$S/a660907426e03e4e9-specs.sh"
fi

echo "######## bars"
WANT_ANCHOR=55 sh "$S/mt-bars.sh" "$B"

echo "######## width probe -- the axis no LP64 board can see"
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
MTCC="$B/gcc/xgcc -B$B/gcc/ -ftarget-config=$B/lib/gcc/$VER/$TA/specs-config" \
STCC="$SB/gcc/xgcc -B$SB/gcc/" \
  sh "$S/a660907426e03e4e9-widthprobe.sh" 4 4 "$TA"
set +e

if [ -z "${SKIP_STOCK:-}" ]; then
echo "######## STOCK suite"
MT_COMPILE_ONLY=1 MT_MAKEFLAGS=-j10 \
  sh "$S/sc-check.sh" "$SB" "$TA" > /tmp/b-a660907426e03e4e9-stockcheck.log 2>&1
echo "stock check driver rc=$?"
fi

# `WANT_ANCHOR' IS REQUIRED BY `mt-lib.sh' AND `mtcheck.sh' DOES NOT SUPPLY IT.
# Omitted, the whole multi-target run dies in one line -- AFTER the eight-hour
# stock run has already finished -- with a message about an unset variable that
# reads as a broken tree rather than as a missing argument.
echo "######## MULTI-TARGET suite"
MT_COMPILE_ONLY=1 MT_MAKEFLAGS=-j10 WANT_ANCHOR=55 \
  MT_TOOLS_arm_unknown_linux_gnueabihf=$TOOLS/bin \
  sh "$S/mtcheck.sh" "$B" "$TA" > /tmp/b-a660907426e03e4e9-mtcheck.log 2>&1
echo "mt check driver rc=$?"
echo "######## DONE"
