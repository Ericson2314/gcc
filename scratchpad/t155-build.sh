#!/bin/sh
# #155 -- build, and STAMP THE EXIT.
#
# PRINCIPLES: "A LOG BEING WRITTEN LOOKS EXACTLY LIKE A LOG THAT FINISHED."
# <tag>.rc is written only after make RETURNS; t155-score.sh refuses any log
# lacking that stamp.  The stamp file is removed FIRST so a killed build cannot
# leave a stale one behind reading as a completed run.
#
# usage: t155-build.sh <builddir> <tag> [target]
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:?tag}
T=${3:-all-gcc}
J=${J:-8}   # -j16 has failed with NO diagnostic under memory pressure
case "$D" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/Makefile" ] || { echo "FATAL: $D/Makefile missing"; exit 9; }

# The build dir's OWN testimony about which tree it came from -- independent of
# this script by construction (PRINCIPLES section 4).
sd=$(grep -m1 -o '  \$ .*/configure' "$D/config.log" | sed 's|^  \$ ||;s|/configure$||')
want=$(cat "$D/T155-SRCDIR" 2>/dev/null || echo none)
[ "$sd" = "$want" ] || { echo "FATAL: config.log srcdir '$sd' != '$want'"; exit 9; }

rm -f "$D/$TAG.rc" "$D/$TAG.out" "$D/$TAG.err"
sh "$S/eb-shell.sh" "cd $D && make -k -j$J $T" > "$D/$TAG.out" 2> "$D/$TAG.err"
rc=$?
echo "$rc" > "$D/$TAG.rc"
echo "make $T rc=$rc  (stamped $D/$TAG.rc)"
