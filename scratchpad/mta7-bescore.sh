#!/bin/sh
# PER-BACK-END VERDICT from a `make -k all-gcc' log, and the distinction that
# matters: ATTEMPTED is not the same as PASSED, and SILENT is neither.
#
# Every per-back-end object in this build is compiled into `mt-<cpu>/' (or
# `mtd-<cpu>/'), and every `make[N]: *** [...: mt-<cpu>/foo.o] Error' names its
# back end in the target path.  So:
#
#   ATTEMPTED   the log contains a compile command producing mt-<cpu>/...
#   FAILED      the log contains a make-level Error for an mt-<cpu>/... target
#   PASSED      attempted and not failed
#   NOT-ATTEMPTED  neither -- under `make -k' a back end whose prerequisite
#                  died is never reached, and that silence must be reported by
#                  name rather than scored as a pass.
#
# usage: mta7-bescore.sh <logfile> <backend-cpu-list-file>
set -u
LOG=${1:?log}
BE=${2:?cpu list}
[ -s "$LOG" ] || { echo "FATAL: $LOG empty/missing"; exit 9; }
[ -s "$BE" ]  || { echo "FATAL: $BE empty/missing"; exit 9; }

natt=0; npass=0; nfail=0; nno=0
for b in $(grep -v '^#' "$BE" | grep .); do
  att=$(grep -c -e "mt-$b/" -e "mtd-$b/" -e "\-$b\.o" "$LOG")
  fail=$(grep -E "^make.*\*\*\* \[" "$LOG" | grep -c -e "mt-$b/" -e "mtd-$b/" -e "\-$b\.o")
  if [ "$att" = 0 ]; then v=NOT-ATTEMPTED; nno=$((nno+1))
  elif [ "$fail" != 0 ]; then v=FAILED; nfail=$((nfail+1)); natt=$((natt+1))
  else v=PASSED; npass=$((npass+1)); natt=$((natt+1))
  fi
  printf '%-12s %-14s mentions=%-6s makeerrors=%s\n' "$b" "$v" "$att" "$fail"
done
echo
echo "attempted=$natt passed=$npass failed=$nfail not-attempted=$nno"
