#!/bin/sh
# #155 -- emit one line per build as it STAMPS, then exit.
#
# Waits on the .rc stamp, never on the log: a log being written looks exactly
# like a log that finished.
set -u
B=/tmp/b-af064528c538fd406-4before
A=/tmp/b-af064528c538fd406-4after
db=0; da=0
while true; do
  if [ "$db" = 0 ] && [ -f "$B/before.rc" ]; then
    n=$(grep -c 'multiple definition of' "$B/before.err" || true)
    u=$(grep -c 'undefined reference to' "$B/before.err" || true)
    c=NO; [ -x "$B/gcc/cc1" ] && c=YES
    echo "BEFORE stamped rc=$(cat "$B/before.rc") multdef-lines=$n undef-lines=$u cc1=$c"
    db=1
  fi
  if [ "$da" = 0 ] && [ -f "$A/after.rc" ]; then
    n=$(grep -c 'multiple definition of' "$A/after.err" || true)
    u=$(grep -c 'undefined reference to' "$A/after.err" || true)
    c=NO; [ -x "$A/gcc/cc1" ] && c=YES
    echo "AFTER stamped rc=$(cat "$A/after.rc") multdef-lines=$n undef-lines=$u cc1=$c"
    da=1
  fi
  [ "$db" = 1 ] && [ "$da" = 1 ] && break
  sleep 60
done
