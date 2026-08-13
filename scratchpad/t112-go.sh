#!/bin/sh
# Task #112 build driver: run t112-build.sh with LOG as the log stem.
# Kept as a script because the harness refuses inline redirections here.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315/scratchpad
LOG=${LOG:-/tmp/b112}
"$S/t112-build.sh" "$@" > "$LOG.log" 2> "$LOG.err"
rc=$?
echo "rc=$rc  stderr=$(wc -l < "$LOG.err") lines  warning:=$(grep -c 'warning:' "$LOG.err")"
exit $rc
