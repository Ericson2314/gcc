#!/bin/sh
# Run t78-build.sh with LOG as the log stem.  Redirections live here because
# the harness refuses them inline for worktree-isolated agents.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a4f7386f72ea30a8c/scratchpad
LOG=${LOG:-/tmp/b78}
"$S/t78-build.sh" "$@" > "$LOG.log" 2> "$LOG.err"
rc=$?
echo "rc=$rc  stderr=$(wc -l < "$LOG.err") lines  warning:=$(grep -c 'warning:' "$LOG.err")"
exit $rc
