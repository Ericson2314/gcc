#!/bin/sh
# IS THIS BACK END'S RESULT STABLE?  N runs of the same cc1 invocation, counting
# distinct (rc, md5) outcomes.  Copy of ta76-flaky.sh with this worktree's build
# dir guard and an ASAN log split out per run.
#
# WHY: a single run cannot tell "this back end emits" from "this back end
# corrupts the heap", and it fails towards the green -- the first mips run ever
# taken returned rc=0 and would have been recorded as "emits".
#
# usage: tab1-flaky.sh <builddir> <triple> <input.c> <-O level> [runs]
set -u
D=${1:?build dir}; T=${2:?triple}; IN=${3:?input}; OPT=${4:--O2}; N=${5:-12}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=${MT_CFG:-$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)}
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }
O=$D/tab1-flaky; mkdir -p "$O"
tag=$T$(echo "$OPT" | tr -d ' -')
: > "$O/$tag.outcomes"
i=0
while [ "$i" -lt "$N" ]; do
  i=$((i+1))
  # handle_segv=2:allow_user_segv_handler=0 -- GCC installs its OWN SIGSEGV
  # handler (`crash_signal', toplev.cc:329), so a fault that ASAN would have
  # described as a use-after-free or a wild read is printed by GCC as a bare
  # "internal compiler error: Segmentation fault" and ASAN says nothing at all.
  # An empty ASAN log next to a crashing cc1 is that, not a clean run.
  ( cd "$D/gcc" && ASAN_OPTIONS=detect_leaks=0:handle_segv=2:allow_user_segv_handler=0:log_path="$O/$tag.$i.asan" \
      UBSAN_OPTIONS=print_stacktrace=1 \
      timeout 900s ./cc1 -quiet -nostdinc "$OPT" \
      -ftarget-config="$CFG" "$IN" -o "$O/$tag.$i.s" ) \
      > /dev/null 2> "$O/$tag.$i.err"
  rc=$?
  md5=$(md5sum < "$O/$tag.$i.s" 2>/dev/null | cut -c1-12)
  echo "rc=$rc md5=$md5" >> "$O/$tag.outcomes"
done
echo "$T $OPT, $N runs, cfg $CFG:"
sort "$O/$tag.outcomes" | uniq -c
n=$(sort -u "$O/$tag.outcomes" | grep -c .)
if [ "$n" = 1 ]; then echo "STABLE"; else echo "UNSTABLE -- $n distinct outcomes"; fi
echo "asan logs: $(ls "$O/$tag".*.asan.* 2>/dev/null | wc -l)"
