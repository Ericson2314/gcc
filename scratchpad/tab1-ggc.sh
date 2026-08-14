#!/bin/sh
# IS THE REMAINING NONDETERMINISM THE GARBAGE COLLECTOR?
#
# ASAN sees nothing: the fault is `SEGV on unknown address ... can not provide
# additional info', i.e. a pointer into no ASAN-known region.  GGC allocates
# its own pages with mmap and reuses them itself, so an object collected while
# still referenced, or a missing GC marker, is INVISIBLE to ASAN by
# construction -- and it is nondeterministic and ASLR-sensitive, which is the
# whole classification we have.
#
# TWO ARMS, both-sided on purpose.  A one-sided "it crashed more" proves
# nothing:
#   GCMAX -- collect at every opportunity (`--param ggc-min-expand=0
#            --param ggc-min-heapsize=0').  If the bug is a collected-too-soon
#            object, this should make it FIRE EVERY TIME.
#   GCOFF -- effectively never collect (huge thresholds).  If the bug is GC,
#            this should make it STOP.
# If both arms look like the baseline, the GC hypothesis is refuted and that
# is the result.
#
# usage: tab1-ggc.sh <builddir> <triple> <input.c> <-O level> [runs]
set -u
D=${1:?build dir}; T=${2:?triple}; IN=${3:?input}; OPT=${4:--O2}; N=${5:-6}
case "$D" in
  */b-agent-ab1fcb485731b7a4d*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=$(ls "$D"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] || { echo "FATAL: no specs-config for $T"; exit 9; }
O=$D/tab1-ggc; mkdir -p "$O"

run_arm () {
  arm=$1; shift
  : > "$O/$T.$arm.outcomes"
  i=0
  while [ "$i" -lt "$N" ]; do
    i=$((i+1))
    ( cd "$D/gcc" && \
      ASAN_OPTIONS=detect_leaks=0:handle_segv=2:allow_user_segv_handler=0 \
      timeout 900s ./cc1 -quiet -nostdinc "$OPT" -ftarget-config="$CFG" \
        "$@" "$IN" -o "$O/$T.$arm.$i.s" ) > /dev/null 2> "$O/$T.$arm.$i.err"
    rc=$?
    where=$(grep -m1 -h 'during .* pass:' "$O/$T.$arm.$i.err" | cut -c1-40)
    echo "rc=$rc ${where:-no-crash}" >> "$O/$T.$arm.outcomes"
    i=$i
  done
  echo "--- $arm ($*)"
  sort "$O/$T.$arm.outcomes" | uniq -c
}

run_arm BASE
run_arm GCMAX --param ggc-min-expand=0 --param ggc-min-heapsize=0
run_arm GCOFF --param ggc-min-expand=1000000 --param ggc-min-heapsize=4194304
