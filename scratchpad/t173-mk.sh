#!/bin/sh
# #173 -- generate just multi-target-md.mk in a build dir (no compile).
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-a7d1e0*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
sh "$S/eb-shell.sh" "cd $D && make configure-gcc && cd gcc && make multi-target-md.mk" \
  > "$D/mk.out" 2> "$D/mk.err"
echo "rc=$?"
tail -3 "$D/mk.err"
wc -l "$D/gcc/multi-target-md.mk"
