#!/bin/sh
# Append the #78/#51 handover to STATE.md.  A script because the harness
# refuses inline redirections for a worktree-isolated agent.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a4f7386f72ea30a8c
SRC=${SRC:-/tmp/t78/state-append.md}
[ -s "$SRC" ] || { echo "FATAL: no $SRC"; exit 9; }
[ -f "$W/scratchpad/STATE.md" ] || { echo "FATAL: no STATE.md"; exit 9; }
before=$(wc -l < "$W/scratchpad/STATE.md")
cat "$SRC" >> "$W/scratchpad/STATE.md" || exit 9
after=$(wc -l < "$W/scratchpad/STATE.md")
echo "STATE.md $before -> $after lines (+$((after - before)))"
[ "$after" -gt "$before" ] || { echo "FATAL: nothing was appended"; exit 9; }
