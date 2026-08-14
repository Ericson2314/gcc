#!/bin/sh
# #150 -- build cc1 in a t150-conf.sh build dir.  $1 = build dir, $2 = target.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
T=${2:-cc1}
case "$D" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
# The build dir's OWN testimony about which tree it came from, re-checked at
# every build: a second agent reconfiguring this path is what this catches.
grep -q 'worktrees/agent-ad0e44242408b7fde/configure' "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name this worktree"; exit 9; }
# Top level, not $D/gcc: the gcc/ subdir does not exist until the top-level
# make configures it.  PRINCIPLES section 5 warns about the opposite mistake
# (running make at the top level when cc1 builds in gcc/); both are real, so
# this drives the top level for configure-stage targets and gcc/ once it is
# there.
if [ -d "$D/gcc" ]; then
  sh "$S/eb-shell.sh" "cd $D/gcc && make -k -j8 $T" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
else
  sh "$S/eb-shell.sh" "cd $D && make -k -j8 all-gcc" \
    > "$D/make-$T.out" 2> "$D/make-$T.err"
fi
rc=$?
echo "make $T rc=$rc"
echo "stderr lines: $(wc -l < "$D/make-$T.err")"
echo "error: lines: $(grep -c 'error:' "$D/make-$T.err" || true)"
