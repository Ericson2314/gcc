#!/bin/sh
# Progress read on a detached mt-build.sh run.
#
# THE STAMP IS THE ONLY THING THAT SAYS THE RUN FINISHED.  PRINCIPLES: "a log
# being written looks exactly like a log that finished"; an agent withdrew two
# figures because both were read mid-build.  So this prints RUNNING/FINISHED
# from the `.rc' file's existence, first, before any count -- and every count
# below a RUNNING line is explicitly labelled provisional.
# usage: agent-a13057f203eb4821c-status.sh <builddir> <tag>
set -u
D=${1:?build dir}; TAG=${2:-all-gcc}
if [ -f "$D/$TAG.rc" ]; then
  echo "FINISHED rc=$(cat "$D/$TAG.rc")"
  ST=final
else
  echo "RUNNING (no $TAG.rc stamp) -- every figure below is PROVISIONAL"
  ST=provisional
fi
for f in log err; do
  [ -f "$D/$TAG.$f" ] && printf '  %-4s %8s lines\n' "$f" "$(wc -l < "$D/$TAG.$f")"
done
if [ -f "$D/$TAG.err" ]; then
  printf '  %-22s %s (%s)\n' 'error: lines'        "$(grep -c 'error:' "$D/$TAG.err")" "$ST"
  printf '  %-22s %s (%s)\n' 'multiple definition' "$(grep -c 'multiple definition' "$D/$TAG.err")" "$ST"
  printf '  %-22s %s (%s)\n' 'undefined reference' "$(grep -c 'undefined reference' "$D/$TAG.err")" "$ST"
  printf '  %-22s %s (%s)\n' 'Killed/signal 9'     "$(grep -c 'Killed\|signal 9' "$D/$TAG.err")" "$ST"
fi
echo "  last log line:"
tail -1 "$D/$TAG.log" 2>/dev/null | cut -c1-160
