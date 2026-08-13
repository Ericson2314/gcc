#!/bin/sh
# THE ACCEPTANCE NUMBER: how many back ends got objects built, and how many
# diagnostics there were, in ONE build dir.
#
# Objects, not log silence.  With `make -k' a back end whose prerequisite
# failed is never attempted, and "not attempted" and "passed" are the same
# silence in the log -- mtN-classify.sh says so and this is the other half of
# it: mt-<cpu>/*.o either exists or it does not.
#
# usage: mtO-score.sh <builddir> <logfile>
set -e
D=${1:?build dir}
LOG=${2:?log}
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc is not a directory"; exit 9; }
[ -s "$LOG" ] || { echo "FATAL: $LOG is empty or missing"; exit 9; }

# Assert the build dir is the one this worktree configured, per PRINCIPLES 4.
sd=$(sed -n 's/^  \$ .*configure.*/&/p' "$D/config.log" | head -1)
grep -q 'agent-a5d68220b57a0d95a' "$D/config.log" \
  || { echo "FATAL: $D/config.log does not name this worktree"; exit 9; }

nd=0; nb=0
for d in "$D"/gcc/mt-*/; do
  [ -d "$d" ] || continue
  nd=$((nd+1))
  n=$(ls "$d"*.o 2>/dev/null | wc -l)
  printf '%-14s %s\n' "$(basename "$d")" "$n"
  [ "$n" -gt 0 ] && nb=$((nb+1))
done
echo
echo "mt-<cpu> directories:            $nd"
echo "back ends with at least one .o:  $nb"
echo "error: lines in log:             $(grep -c 'error:' "$LOG" || true)"
echo "log lines:                       $(wc -l < "$LOG")"
