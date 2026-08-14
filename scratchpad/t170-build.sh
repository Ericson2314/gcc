#!/bin/sh
# #170 -- build cc1 in the eleven-back-end build dir.
#
# PRINCIPLES section 4: "a log being written looks exactly like a log that
# finished".  The rc stamp is written ONLY after make returns, and the scorer
# below refuses a log without one.
#
# usage: t170-build.sh <builddir> [tag]
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
TAG=${2:-cc1}
case "$D" in
  */b-a697b5bfd5294f5e8*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
# Top level, not $D/gcc: the gcc subdir is configured lazily BY make, so it
# does not exist until all-gcc has run once.  (PRINCIPLES section 5's "make in
# the wrong directory" trap, met from the other side.)
[ -f "$D/Makefile" ] || { echo "FATAL: $D not configured"; exit 9; }
rm -f "$D/$TAG.rc"
sh "$S/eb-shell.sh" "cd $D && make -k -j8 all-gcc" \
  > "$D/$TAG.log" 2> "$D/$TAG.err"
rc=$?
echo "$rc" > "$D/$TAG.rc"
echo "make rc=$rc  (stamped $D/$TAG.rc)"
echo "== multiple definition"
grep -c 'multiple definition' "$D/$TAG.err" || true
echo "== undefined reference (distinct names)"
grep -o "undefined reference to \`[^']*'" "$D/$TAG.err" | sort -u | head -40
ls -l "$D/gcc/cc1" 2>&1
