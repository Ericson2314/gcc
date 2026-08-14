#!/bin/sh
# #174 -- build in a build dir configured by t174-conf.sh.
# usage: t174-build.sh <builddir> <tag> <make-target...>
#
# The `.rc' stamp is written only after make RETURNS, and the scorer must
# refuse a log without one: a log being written looks exactly like a log that
# finished (PRINCIPLES sec 4).
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; shift
TAG=${1:?tag}; shift
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SNAP=$(cat "$D/MY-SRC")
n=$(grep -c MULTI_TARGET "$SNAP/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:?set WANT_ANCHOR}" ] || {
  echo "FATAL: $SNAP anchor=$n, expected exactly $WANT_ANCHOR"; exit 9; }
( cd "$SNAP" && git diff --quiet ) || { echo "FATAL: $SNAP is dirty"; exit 9; }
grep -q "$SNAP" "$D/config.log" || { echo "FATAL: $D was configured from another tree"; exit 9; }

rm -f "$D/$TAG.rc"
set +e
sh "$S/eb-shell.sh" "cd $D && make -j8 $*" > "$D/$TAG.log" 2> "$D/$TAG.err"
rc=$?
set -e
echo "$rc" > "$D/$TAG.rc"
echo "$TAG rc=$rc  stderr $(wc -l < "$D/$TAG.err") lines"
grep -c '^Killed\|signal 9' "$D/$TAG.err" || true
tail -5 "$D/$TAG.err"
