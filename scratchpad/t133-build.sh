#!/bin/sh
# #119 -- build driver.  $1 = make goals.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
J=${J:-8}
TAG=${TAG:-build}
sh "$S/eb-shell.sh" "cd $B && make -j$J $*" > "$B/$TAG.out" 2> "$B/$TAG.err"
rc=$?
echo "rc=$rc  goals: $*"
echo "stderr lines: $(wc -l < "$B/$TAG.err")  warning: $(grep -c 'warning:' "$B/$TAG.err")"
tail -8 "$B/$TAG.err"
exit $rc
