#!/bin/sh
# STOCK CONTROL, part C -- `make all-gcc' in the stock cross build dir.
#
# `all-gcc' ONLY, deliberately: the multi-target board was taken with no target
# libgcc anywhere, and the control has to share that.  Building libgcc here
# would give stock a runtime the other side does not have, and every link test
# would then differ for a reason that has nothing to do with this project.
#
# The exit code is STAMPED into build.rc after make returns (PRINCIPLES 4: a
# log being written looks exactly like a log that finished).
#
# usage: sc-build.sh <builddir> [-jN]
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
J=${2:--j12}
[ -f "$D/Makefile" ] || { echo "FATAL: $D is not configured"; exit 9; }
SRC=$(cat "$D/MY-SRC") || exit 9
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = 0 ] || { echo "FATAL: $D was configured from $SRC, anchor=$n, not stock"; exit 9; }
# THE TOOLS DIR IS READ BACK FROM THE BUILD DIR, not hardcoded and not
# re-derived.  sc-conf.sh stamps TARGET-TOOLS with the binutils the configure
# actually recorded; putting a different directory on PATH here would assemble
# with another target's tools and say nothing.  Older build dirs predate the
# stamp, so the historical value is the fallback -- named, so it is visible.
TOOLS=$(cat "$D/TARGET-TOOLS" 2>/dev/null || echo /tmp/tools-agent-a3464debf6893de84/bin)
[ -d "$TOOLS" ] || { echo "FATAL: no tools dir $TOOLS"; exit 9; }
rm -f "$D/build.rc"
sh "$S/eb-shell.sh" "cd $D && PATH=$TOOLS:\$PATH make $J all-gcc" \
  > "$D/build.out" 2> "$D/build.err"
rc=$?
echo "$rc" > "$D/build.rc"
echo "make all-gcc rc=$rc"
echo "  'error:' lines: $(grep -c 'error:' "$D/build.err" || true)"
tail -5 "$D/build.err"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }
[ -x "$D/gcc/xgcc" ] || { echo "FATAL: no $D/gcc/xgcc"; exit 9; }
ls -la "$D/gcc/cc1" "$D/gcc/xgcc"
exit "$rc"
