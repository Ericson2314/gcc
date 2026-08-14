#!/bin/sh
# STOCK CONTROL, part A -- an IMMUTABLE SNAPSHOT of UNMODIFIED upstream GCC at
# the branch's merge-base, PLUS exactly two testsuite files copied from this
# branch.
#
# WHY A SNAPSHOT OF SOMEBODY ELSE'S COMMIT NEEDS ITS OWN SCRIPT.  Every
# `*-snap.sh' here archives THIS worktree's HEAD and then asserts the
# MULTI_TARGET anchor is the branch's value.  The control needs the opposite
# assert: the tree must be upstream, so `grep -c MULTI_TARGET gcc/Makefile.in'
# must be **0**.  Reusing a branch snap script and "just changing WANT_ANCHOR"
# would have produced a tree that is not upstream and no arm would have said
# so -- the same shape as the 22 FOREIGN-SRC scripts in PRINCIPLES 4.
#
# WHAT IS GRAFTED, AND WHY IT IS NOT A COMPILER CHANGE.  The board being
# compared against was taken with MT_COMPILE_ONLY=1, which is implemented by
# `gcc/testsuite/lib/multi-target.exp' (a dg-do rename) reached through a
# `load_lib' line in `gcc/testsuite/lib/gcc-dg.exp'.  Neither exists upstream.
# Without them the stock side would LINK every `dg-do run' test in a build with
# no target libgcc, i.e. it would carry a uniform link-FAIL floor the
# multi-target side does not -- and the diff would be a measurement of the
# harness, not of the compiler.  So both files are copied in, VERBATIM, and
# nothing under gcc/ except `testsuite/lib/' is touched.  The graft is
# asserted, byte for byte, at the end of this script: an inert .exp is the
# exact failure G5 exists to catch and it is silent.
#
# usage: sc-snap.sh <snapdir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?snapshot dir}

MB=$(cd "$SRC" && git merge-base HEAD upstream/master) || exit 9
[ -n "$MB" ] || { echo "FATAL: no merge-base with upstream/master"; exit 9; }

# The two grafted files come from THIS tree's HEAD, so this tree must be clean
# for the same reason any snapshot's source must be.
( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
  || { echo "FATAL: $SRC is dirty; the grafted testsuite files would not be HEAD"; exit 9; }
BRSHA=$(cd "$SRC" && git rev-parse HEAD)

if [ -d "$D" ]; then chmod -R u+w "$D"; fi
rm -rf "$D"; mkdir -p "$D"
( cd "$SRC" && git archive "$MB" ) | tar -x -C "$D"

# ---- assert this really is upstream, BEFORE grafting anything ----
n=$(grep -c MULTI_TARGET "$D/gcc/Makefile.in" || true)
[ "$n" = 0 ] || { echo "FATAL: snapshot has $n MULTI_TARGET hits in gcc/Makefile.in; it is NOT stock"; exit 9; }
if grep -q 'gcc_backends_arg' "$D/configure"; then
  echo "FATAL: $D/configure has gcc_backends_arg; it is the branch, not upstream"; exit 9
fi
[ ! -f "$D/gcc/multi-target-base.h" ] || { echo "FATAL: branch header present in stock snapshot"; exit 9; }
[ ! -f "$D/gcc/testsuite/lib/multi-target.exp" ] \
  || { echo "FATAL: upstream already has multi-target.exp?  refusing to graft blind"; exit 9; }

# ---- the graft ----
cp "$SRC/gcc/testsuite/lib/multi-target.exp" "$D/gcc/testsuite/lib/multi-target.exp"
G="$D/gcc/testsuite/lib/gcc-dg.exp"
grep -q '^load_lib multi-target.exp$' "$G" \
  && { echo "FATAL: gcc-dg.exp already loads it"; exit 9; }
# INSERT AT THE SAME POINT THE BRANCH DOES.  multi-target.exp wraps `dg-do',
# so it must be loaded after dg.exp; the branch's own line sits immediately
# after `load_lib dg-test-cleanup.exp' and this reproduces that position rather
# than choosing a new one.  Load order is exactly what makes the .exp inert
# instead of wrong, so it is not a free choice.
grep -q '^load_lib dg-test-cleanup.exp$' "$G" \
  || { echo "FATAL: no 'load_lib dg-test-cleanup.exp' anchor line in $G"; exit 9; }
awk '{print} /^load_lib dg-test-cleanup\.exp$/ && !d {print "load_lib multi-target.exp"; d=1}' \
  "$G" > "$G.new" && mv "$G.new" "$G"

# ---- prove the graft landed, both halves ----
cmp "$SRC/gcc/testsuite/lib/multi-target.exp" "$D/gcc/testsuite/lib/multi-target.exp" \
  || { echo "FATAL: grafted multi-target.exp differs from the branch's"; exit 9; }
[ "$(grep -c '^load_lib multi-target.exp$' "$G")" = 1 ] \
  || { echo "FATAL: load_lib line not inserted exactly once"; exit 9; }
echo "$MB" > "$D/STOCK-SHA"
echo "$BRSHA" > "$D/GRAFT-FROM-SHA"
chmod -R a-w "$D" 2>/dev/null || true
echo "stock snapshot $D"
echo "  upstream merge-base   $MB"
echo "  testsuite graft from  $BRSHA (multi-target.exp + one load_lib line)"
echo "  MULTI_TARGET anchor   $n  (must be 0 -- this is the control)"
