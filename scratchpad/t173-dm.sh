#!/bin/sh
# #173 -- BOTH-SIDED proof that a converted file gets its OWN base's tm.h.
#
# A count of surviving `#include "tm.h"' says nothing about which header a
# converted file now opens.  This replays the REAL compile recipe for one
# converted object per base, with `-E -dM' substituted for `-c', and reads
# back a macro that ONLY that base defines.
#
# TWO TRAPS THIS SCRIPT IS BUILT AROUND, both recorded in PRINCIPLES:
#
#  * `-x c++'.  multi-target-macros.h's guard has an `|| !defined
#    (__cplusplus)' arm, so under C every redirect switches off and an agent
#    concluded Pmode was unconverted that way.  The recipe is replayed
#    verbatim, which keeps the C++ front end, and the arm below asserts
#    __cplusplus is in the dump so a silent fall back to C is not possible.
#  * ONE-SIDED EVIDENCE.  Showing i386 gets i386's answer proves nothing
#    unless riscv still gets riscv's.  Both are read, and the script fails if
#    they agree.
set -e
D=${1:?build dir}
[ -f "$D/gcc/Makefile" ] || { echo "FATAL: no $D/gcc/Makefile"; exit 9; }
S=$(cd "$(dirname "$0")" && pwd)
LOG="$D/make-top.out"
[ -f "$LOG" ] || { echo "FATAL: no $LOG to take recipes from"; exit 9; }
[ -f "$D/make-top.rc" ] || { echo "FATAL: $LOG has no .rc stamp; a log being written looks exactly like one that finished"; exit 9; }

probe () {
  base=$1; obj=$2; macro=$3
  # The last recipe that produced this object, verbatim.
  cmd=$(grep -- " -o $obj " "$LOG" | tail -1)
  [ -n "$cmd" ] || { echo "FATAL: no recipe for $obj in $LOG"; exit 9; }
  # -c -> -E -dM, and drop the -o so the dump comes to stdout.
  new=$(printf '%s\n' "$cmd" | sed "s| -c | -E -dM |; s| -o $obj ||")
  out=$(sh "$S/eb-shell.sh" "cd $D/gcc && $new" 2> "$D/dm-$base.err")
  printf '%s\n' "$out" > "$D/dm-$base.txt"
  grep -q '^#define __cplusplus' "$D/dm-$base.txt" \
    || { echo "FATAL: $base dump has no __cplusplus -- it was preprocessed as C, and every multi-target-macros.h redirect is off in that mode"; exit 9; }
  v=$(awk -v m="$macro" '$1 == "#define" && $2 == m { $1=""; $2=""; print; exit }' \
	"$D/dm-$base.txt")
  # ABSENT IS NOT AN ANSWER.  An empty dump reads the same way as a macro that
  # is genuinely undefined, so the probe macro must be one BOTH bases define.
  [ -n "$v" ] || { echo "FATAL: $macro absent from $base's dump"; exit 9; }
  printf '%-10s %-28s %-22s %s\n' "$base" "$obj" "$macro" "$v"
  eval "R_$base=\$v"
}

printf '%-10s %-28s %-22s %s\n' base object macro value
probe i386  mt-i386/i386-c.o          POINTER_SIZE
probe riscv mt-riscv/riscv-c.o        POINTER_SIZE

# Both-sided: one value proves nothing if the other is the same.
if [ "$R_i386" = "$R_riscv" ]; then
  echo "FAIL: both bases read the same value -- that is what a leak looks like"
  exit 1
fi
echo "PASS: the two bases disagree, so each is reading its own tm.h chain"
