#!/bin/sh
# Detached relaunch of the BASELINE board, same reasoning as fixboard.sh.
set -u
cd /home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa1e1db1aead2bffb || exit 1
rm -f /tmp/b-aa1e1db1aead2bffb/check-aarch64-unknown-linux-gnu.rc
WANT_ANCHOR=52 TOOLS=/tmp/tools-aa1e1db1aead2bffb/bin \
OUT=/tmp/w-aa1e1db1aead2bffb/scores \
sh scratchpad/aa1e1db1aead2bffb-score.sh /tmp/b-aa1e1db1aead2bffb base \
   aarch64-sve-acle-asm.exp aarch64-sme-acle-asm.exp
echo "BASEBOARD DONE rc=$?"
