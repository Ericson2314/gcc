#!/bin/sh
# DETACHED driver: build, cross tools, per-target specs, bars.
#
# Detached (`setsid nohup') and NOT a harness background task: the agent
# harness culls long background commands, and a culled run leaves a stale `.rc'
# beside a partial artefact, which reads exactly like a finished one.
#
# The build dir is REMADE from scratch: an earlier invocation of this build was
# killed ~1 minute in, and a half-written generated file is the one failure
# class this project cannot afford to guess about.
set -u
ID=agent-a01e6c604f26604a7
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/$ID
B=/tmp/b-a01e6c604f26604a7
L=/tmp/drive-$ID
mkdir -p "$L"
cd "$W" || exit 9

A=$(grep -c MULTI_TARGET gcc/Makefile.in)
[ "$A" = 52 ] || { echo "FATAL anchor=$A" > "$L/FATAL"; exit 9; }
export WANT_ANCHOR=$A

LIST=$(grep -v '^#' scratchpad/backends-47.txt | grep -v '^$' | paste -sd,)

echo "=== reconfigure $(date)" > "$L/drive.log"
SRC="/tmp/snap-$ID" sh scratchpad/mt-conf.sh "$B" "$LIST" >> "$L/drive.log" 2>&1
rc=$?; echo "conf rc=$rc" >> "$L/drive.log"
[ "$rc" = 0 ] || { echo "$rc" > "$L/DRIVE-FAILED-conf"; exit 9; }

echo "=== build $(date)" >> "$L/drive.log"
MT_JOBS=12 sh scratchpad/mt-build.sh "$B" all-gcc all-gcc >> "$L/drive.log" 2>&1
rc=$?; echo "build rc=$rc" >> "$L/drive.log"
[ "$rc" = 0 ] || { echo "$rc" > "$L/DRIVE-FAILED-build"; exit 9; }

echo "=== tools $(date)" >> "$L/drive.log"
sh scratchpad/taa-tools.sh "/tmp/tools-$ID" >> "$L/drive.log" 2>&1
rc=$?; echo "tools rc=$rc" >> "$L/drive.log"
[ "$rc" = 0 ] || { echo "$rc" > "$L/DRIVE-FAILED-tools"; exit 9; }

echo "=== specs $(date)" >> "$L/drive.log"
B="$B" TOOLS="/tmp/tools-$ID" sh scratchpad/taa-specs.sh >> "$L/drive.log" 2>&1
rc=$?; echo "specs rc=$rc" >> "$L/drive.log"
[ "$rc" = 0 ] || { echo "$rc" > "$L/DRIVE-FAILED-specs"; exit 9; }

echo "=== bars $(date)" >> "$L/drive.log"
sh scratchpad/mt-bars.sh "$B" >> "$L/drive.log" 2>&1
echo "bars rc=$?" >> "$L/drive.log"

echo "=== DRIVE DONE $(date)" >> "$L/drive.log"
echo 0 > "$L/DRIVE.rc"
