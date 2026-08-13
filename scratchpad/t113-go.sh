#!/bin/sh
# Task #112 build driver: run t113-build.sh with LOG as the log stem.
# Kept as a script because the harness refuses inline redirections here.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098/scratchpad
LOG=${LOG:-/tmp/b113}
"$S/t113-build.sh" "$@" > "$LOG.log" 2> "$LOG.err"
rc=$?
echo "rc=$rc  stderr=$(wc -l < "$LOG.err") lines  warning:=$(grep -c 'warning:' "$LOG.err")"
exit $rc
