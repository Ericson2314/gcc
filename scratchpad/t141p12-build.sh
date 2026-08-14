#!/bin/sh
# Task #160: build in the dir configured by t141p12-conf.sh, and STAMP THE EXIT.
#
# A log being written looks exactly like a log that finished (PRINCIPLES
# section 4), so <tag>.rc is written only after make returns and any scorer
# must refuse a log without it.
#
# usage: t141p12-build.sh <builddir> <snapshot-srcdir> [target] [tag]
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
SRC=${2:?snapshot srcdir}
T=${3:-all-gcc}
TAG=${4:-build}
WANT=${WANT_ANCHOR:-48}
# The build dir's own testimony about which srcdir configured it -- independent
# of this script by construction.
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D was not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "$WANT" ] \
  || { echo "FATAL: snapshot anchor is not $WANT"; exit 9; }
rm -f "$D/$TAG.rc"
set +e
sh "$S/eb-shell.sh" "cd $D && make -j8 $T" > "$D/$TAG.out" 2> "$D/$TAG.err"
rc=$?
set -e
echo "$rc" > "$D/$TAG.rc"
echo "$TAG: rc=$rc  out=$(wc -l < "$D/$TAG.out") lines  err=$(wc -l < "$D/$TAG.err") lines"
exit $rc
