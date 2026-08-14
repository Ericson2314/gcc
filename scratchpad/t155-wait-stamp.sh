#!/bin/sh
# #155 -- wait for the AFTER build's .rc STAMP and nothing else.
#
# The stamp, never the log: a log being written looks exactly like a log that
# finished, and an agent here reported two figures from mid-build snapshots and
# had to withdraw both.  t155-build.sh removes the stamp before starting and
# writes it only after make RETURNS, so a killed build leaves no stamp at all.
set -u
A=/tmp/b-af064528c538fd406-4after
until [ -f "$A/after.rc" ]; do sleep 60; done
n=$(grep -c 'multiple definition of' "$A/after.err" || true)
u=$(grep -c 'undefined reference to' "$A/after.err" || true)
c=NO; [ -x "$A/gcc/cc1" ] && c=YES
echo "AFTER stamped rc=$(cat "$A/after.rc") multdef-lines=$n undef-lines=$u cc1=$c"
