#!/bin/sh
# #175 -- ICEs BY SITE, per target, from the merged gcc.log.
#
# This is the column the `gen_nop' fix is supposed to move, and it is counted
# from the LOG rather than the .sum because a .sum records an ICE as an
# ordinary FAIL and says nothing about where the compiler died.  The baseline
# it is compared against is scratchpad/T173-board.txt / T173-BASELINE.md:
#
#   x86_64                       aarch64
#     2 Segmentation fault        5103 in extract_insn, at recog.cc:2892
#     2 deliberate-ICE test        509 in gen_lowpart_general, at rtlhooks.cc:57
#                                   68 in aarch64_output_casesi, aarch64.cc:14446
#                                   26 in get_attr_type, at aarch64.md:49049
#
# KILLED IS COUNTED SEPARATELY AND NEVER SUBTRACTED.  An OOM-killed cc1 records
# as `internal compiler error: Killed', which would otherwise land in this
# table as a compiler defect at an invented site.
set -u
B=${1:?build dir}; shift
[ $# -ge 1 ] || { echo "FATAL: name at least one target triple"; exit 9; }

for T in "$@"; do
  LOG="$B/gcc/testsuite.$T/gcc/gcc.log"
  echo "== $T"
  if [ ! -f "$LOG" ]; then echo "   REFUSED: no $LOG"; continue; fi
  n=$(grep -c 'internal compiler error' "$LOG" || true)
  echo "   internal compiler error lines: $n"
  # Non-vacuity: zero is a real answer here, but it must be distinguishable
  # from "the grep never matched because the log is not what I think it is".
  echo "   (log lines: $(wc -l < "$LOG"))"
  grep -o 'internal compiler error: .*' "$LOG" \
    | sed 's/internal compiler error: //; s/[0-9][0-9]*$//' \
    | sort | uniq -c | sort -rn | head -12 | sed 's/^/     /'
  k=$(grep -c -iE 'internal compiler error: Killed|terminated by signal 9|out of memory|virtual memory exhausted' "$LOG" || true)
  echo "   KILLED (machine contamination, NOT a compiler defect, never subtracted): $k"
done
