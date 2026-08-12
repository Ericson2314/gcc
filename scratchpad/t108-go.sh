#!/bin/sh
# Task #107 build driver: run t108-build.sh with LOG as the log stem.
# Kept as a script because the harness refuses inline redirections here.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7d5fb84bdd2264ac/scratchpad
LOG=${LOG:-/tmp/b108}
"$S/t108-build.sh" "$@" > "$LOG.log" 2> "$LOG.err"
rc=$?
echo "rc=$rc  stderr=$(wc -l < "$LOG.err") lines  warning:=$(grep -c 'warning:' "$LOG.err")"
exit $rc
