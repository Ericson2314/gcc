#!/bin/sh
# IS THIS BACK END'S RESULT STABLE?  Run the same cc1 invocation N times and
# count distinct (rc, md5) outcomes.
#
# WHY THIS EXISTS.  mips64 at -O2 exited 0 and emitted 4262 bytes on one run
# and segfaulted in GIMPLE `fixup_cfg' on the next, with the same compiler,
# the same input and the same config -- and under gdb (which disables ASLR)
# it never faulted at all.  That is the signature of memory corruption, not
# of a missing per-base answer, and a single run would have recorded either
# "emits" or "SIGSEGV" as if it were the result.
#
# A back end that is not STABLE is not scored as emitting.
#
# usage: ta76-flaky.sh <builddir> <triple> <input.c> <-O level> [runs]
set -u
D=${1:?build dir}; T=${2:?triple}; IN=${3:?input}; OPT=${4:--O2}; N=${5:-12}
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }
O=$D/ta76-flaky; mkdir -p "$O"
: > "$O/$T.outcomes"
i=0
while [ "$i" -lt "$N" ]; do
  i=$((i+1))
  ( cd "$D/gcc" && timeout 300s ./cc1 -quiet -nostdinc "$OPT" \
      -ftarget-config="$CFG" "$IN" -o "$O/$T.$i.s" ) \
      > /dev/null 2> "$O/$T.$i.err"
  rc=$?
  md5=$(md5sum < "$O/$T.$i.s" 2>/dev/null | cut -c1-12)
  echo "rc=$rc md5=$md5" >> "$O/$T.outcomes"
done
echo "$T $OPT, $N runs:"
sort "$O/$T.outcomes" | uniq -c
n=$(sort -u "$O/$T.outcomes" | grep -c .)
if [ "$n" = 1 ]; then echo "STABLE"; else echo "UNSTABLE -- $n distinct outcomes"; fi
