#!/bin/sh
# #155 -- wait for any build's .rc STAMP, and report the link outcome.
# usage: t155-wait-any.sh <builddir> <tag>
set -u
D=${1:?build dir}
T=${2:?tag}
case "$D" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
until [ -f "$D/$T.rc" ]; do sleep 60; done
n=$(grep -c 'multiple definition of' "$D/$T.err" || true)
u=$(grep -c 'undefined reference to' "$D/$T.err" || true)
c=NO; [ -x "$D/gcc/cc1" ] && c=YES
echo "$T stamped rc=$(cat "$D/$T.rc") multdef-lines=$n undef-lines=$u cc1=$c"
