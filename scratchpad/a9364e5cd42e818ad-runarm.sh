#!/bin/sh
# The arm MULTI-TARGET suite run, against the PRESERVED stock board.
#
# `a660907426e03e4e9-runarm.sh' runs BOTH sides.  Only the multi-target side is
# re-run here: the stock control is upstream `c31b7a09eea', nothing in this task
# touches it, and its board survives verbatim and gzipped at
# `/tmp/keep-agent-a660907426e03e4e9/stock-arm-gcc.sum.gz'.  Re-running it would
# cost eight hours to reproduce a file that already exists.
#
# THAT IS ONLY LEGITIMATE BECAUSE THE STOCK SIDE IS PINNED AND CHECKABLE, and
# it is checked: the preserved sum's own totals are re-derived below and must
# match the figures A660907426E03E4E9-ARM-BOARD.md 2 records.  A stock board
# quoted from memory rather than from a file is exactly the "attribution needs
# evidence" failure, and a `.sum` that has been overwritten by a later run looks
# identical to one that has not (INSTRUMENTS.md).
#
# `WANT_ANCHOR' IS REQUIRED BY `mt-lib.sh' AND `mtcheck.sh' DOES NOT SUPPLY IT.
# Omitted, the run dies in one line with a message about an unset variable that
# reads as a broken tree rather than as a missing argument.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the 47-base build dir}
TOOLS=${TOOLS:?set TOOLS to the cross-tools dir}
TA=arm-unknown-linux-gnueabihf
KEEP=/tmp/keep-agent-a660907426e03e4e9

# THE STAMP MUST BE `all-gcc.rc`, NOT WHATEVER TAG THE BUILD HAPPENED TO USE.
# `mtcheck.sh`'s rename sweep looks for `all-gcc.rc` or `make-cc1.rc` by name and
# refuses otherwise, "because a skipped sweep reads exactly like a clean one".
# A build stamped `fix2.rc` is a perfectly good build that the sweep cannot
# certify, and the fix is to re-run `mt-build.sh` under the tag it expects --
# NOT to create the stamp by hand, which is forging the very certificate the
# guard exists to check.
[ "$(cat "$B/all-gcc.rc" 2>/dev/null || echo x)" = 0 ] \
  || { echo "FATAL: $B/all-gcc.rc missing or non-zero -- rebuild with tag all-gcc"; exit 9; }
[ -f "$KEEP/stock-arm-gcc.sum.gz" ] || { echo "FATAL: no preserved stock sum"; exit 9; }

echo "######## the preserved stock board, re-derived from the FILE"
zcat "$KEEP/stock-arm-gcc.sum.gz" | \
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\):.*/\1/p' | \
  sort | uniq -c | sort -rn
echo "   (A660907426E03E4E9-ARM-BOARD.md 2 records: PASS 148432  FAIL 15997"
echo "    XPASS 8  XFAIL 1307  UNSUPPORTED 10573  UNRESOLVED 12831  ERROR 8)"

echo "######## MULTI-TARGET suite"
MT_COMPILE_ONLY=1 MT_MAKEFLAGS=${MT_MAKEFLAGS:--j10} WANT_ANCHOR=55 \
  MT_TOOLS_arm_unknown_linux_gnueabihf=$TOOLS/bin \
  sh "$S/mtcheck.sh" "$B" "$TA" > /tmp/b-a9364e5cd42e818ad-mtcheck.log 2>&1
echo "mt check driver rc=$?"
echo "######## DONE"
