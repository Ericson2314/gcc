#!/bin/sh
# usage: mtN-make.sh <builddir> <subdir-or-.> <logfile> <make args...>
# Runs make inside the dev shell, logs to <logfile>, prints rc.
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; shift
SUB=${1:?subdir}; shift
LOG=${1:?log}; shift
sh "$S/eb-shell.sh" "cd $D/$SUB && make $*" > "$LOG" 2>&1
rc=$?
echo "rc=$rc log=$LOG"
exit $rc
