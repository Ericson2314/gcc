#!/bin/sh
# Detached relaunch of the fixed-build board.  The harness culls background
# tasks, and a culled `mtcheck' leaves a STALE `check-<triple>.rc' beside a
# PARTIAL gcc.sum -- the exact shape PRINCIPLES warns about, where the stamp
# says a run finished and the file no longer belongs to it.  Clear the stamp
# first so a copy cannot be authorised by the previous run's rc.
set -u
cd /home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa1e1db1aead2bffb || exit 1
rm -f /tmp/b-aa1e1db1aead2bffb-fix/check-aarch64-unknown-linux-gnu.rc
WANT_ANCHOR=52 TOOLS=/tmp/tools-aa1e1db1aead2bffb/bin \
OUT=/tmp/w-aa1e1db1aead2bffb/scores \
sh scratchpad/aa1e1db1aead2bffb-score.sh /tmp/b-aa1e1db1aead2bffb-fix fix \
   aarch64-sve-acle-asm.exp aarch64-sme-acle-asm.exp
echo "FIXBOARD DONE rc=$?"
