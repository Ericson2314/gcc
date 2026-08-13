#!/bin/sh
# Task #45/#98 build driver: run t45-build.sh with LOG as the log stem.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-add93fb43c802e701/scratchpad
LOG=${LOG:-/tmp/b45log}
sh "$S/t45-build.sh" "$@" > "$LOG.log" 2> "$LOG.err"
rc=$?
echo "rc=$rc  stderr=$(wc -l < "$LOG.err") lines  warning:=$(grep -c 'warning:' "$LOG.err")"
exit $rc
