#!/bin/sh
# DETACHED four-target board run at tip.
#
# `setsid nohup' and not a harness background task: the harness culls long
# background commands and a culled mtcheck leaves a STALE `check-<triple>.rc'
# beside a PARTIAL gcc.sum -- the stamp then certifies a run that did not
# finish.  mtcheck.sh clears the stamp before each target for the same reason,
# but a cull between targets would still leave the PREVIOUS target's stamp, so
# they are all removed here first.
#
# MT_MAKEFLAGS UNSET SILENTLY MEANS -j1 and nothing says so; one agent's first
# run was heading for ~9h per arm.  It is set explicitly and echoed.
set -u
ID=agent-a01e6c604f26604a7
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/$ID
B=/tmp/b-a01e6c604f26604a7
T1=x86_64-pc-linux-gnu
T2=aarch64-unknown-linux-gnu
T3=riscv64-unknown-linux-gnu
T4=s390x-ibm-linux-gnu
L=/tmp/board-$ID
mkdir -p "$L"
cd "$W" || exit 9

A=$(grep -c MULTI_TARGET gcc/Makefile.in)
[ "$A" = 52 ] || { echo "FATAL anchor=$A"; exit 9; }
export WANT_ANCHOR=$A

for T in "$T1" "$T2" "$T3" "$T4"; do rm -f "$B/check-$T.rc"; done

echo "=== board start $(date); load $(cat /proc/loadavg)" > "$L/board.log"
echo "MT_MAKEFLAGS=-j16 MT_COMPILE_ONLY=1" >> "$L/board.log"

MT_COMPILE_ONLY=1 \
MT_MAKEFLAGS=-j16 \
MT_TOOLS_x86_64_pc_linux_gnu=/tmp/tools-$ID/bin \
MT_TOOLS_aarch64_unknown_linux_gnu=/tmp/tools-$ID/bin \
MT_TOOLS_riscv64_unknown_linux_gnu=/tmp/tools-$ID/bin \
MT_TOOLS_s390x_ibm_linux_gnu=/tmp/tools-$ID/bin \
sh scratchpad/mtcheck.sh "$B" "$T1" "$T2" "$T3" "$T4" >> "$L/board.log" 2>&1
rc=$?
echo "=== board end $(date) rc=$rc; load $(cat /proc/loadavg)" >> "$L/board.log"

# PRESERVE THE ARTEFACTS PER RUN.  mtcheck.sh writes every run's gcc.sum and
# gcc.log under testsuite.<triple>/, which is per target -- but any LATER run
# in this build dir overwrites them, and a destroyed file reads exactly like a
# present one.  Copy before anything else can touch them.
for T in "$T1" "$T2" "$T3" "$T4"; do
  d="$B/gcc/testsuite.$T/gcc"
  [ -f "$d/gcc.sum" ] && cp "$d/gcc.sum" "$L/$T.sum"
  [ -f "$d/gcc.log" ] && cp "$d/gcc.log" "$L/$T.log"
  [ -f "$B/check-$T.rc" ] && cp "$B/check-$T.rc" "$L/$T.rc"
done
echo "$rc" > "$L/BOARD.rc"
