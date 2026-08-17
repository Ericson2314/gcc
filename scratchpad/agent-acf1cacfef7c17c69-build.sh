#!/bin/sh
# agent-acf1cacfef7c17c69-build.sh -- snapshot + configure + block-build the
# 47-base tree for the TARGET_HAS_FMV_TARGET_ATTRIBUTE task.
#
# No forked logic: it calls mt-conf.sh and mt-build.sh unmodified, from THIS
# worktree's scratchpad (mt-lib.sh derives its build-dir guard tag from the
# running script's own path, so a snapshot copy cannot derive one), while SRC
# points at the immutable snapshot.
#
# The snapshot path carries the SHA as well as the worktree id, per PRINCIPLES:
# a build dir re-reads its srcdir long after configure, so overwriting a
# snapshot in place makes the next arm measure a different commit and say so
# with a green.
#
# usage: [SHA=<sha>] sh agent-acf1cacfef7c17c69-build.sh
set -eu
ID=acf1cacfef7c17c69
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-$ID
cd "$W"

SHA=${SHA:-$(git rev-parse --short HEAD)}
SRC=/tmp/snap-$SHA-agent-$ID
B=/tmp/b-$ID

# The anchor is a property of the tree, not of anybody's belief about it.
#
# 52 UNTIL `56890d52173', 55 AFTER, and the three lines are a COMMENT BLOCK in
# `gcc/Makefile.in' explaining `MULTI_TARGET_MD_TU' -- exactly the shape
# PRINCIPLES predicts ("the last three moves came from comment prose, not from
# mechanism"), and exactly the shape that makes an agent diff the rules, find
# nothing, and conclude a script is broken.  It is a content hash of one file,
# comments deliberately included, which is what makes it catch a stale tree.
# Do not narrow the grep; update the number.
WANT=${MT_WANT_ANCHOR:-55}
A=$(grep -c MULTI_TARGET gcc/Makefile.in)
[ "$A" = "$WANT" ] || { echo "FATAL: anchor $A != $WANT in $W"; exit 9; }

if [ ! -r "$SRC/SNAP-SHA" ]; then
  rm -rf "$SRC"; mkdir -p "$SRC"
  git archive "$SHA" | tar -x -C "$SRC"
  echo "$SHA" > "$SRC/SNAP-SHA"
  chmod -R a-w "$SRC"
fi
[ -r "$SRC/SNAP-SHA" ] || { echo "FATAL: no SNAP-SHA in $SRC"; exit 9; }
SA=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$SA" = "$A" ] || { echo "FATAL: snapshot anchor $SA != $A"; exit 9; }

LIST=$(grep -v '^#' "$SRC/scratchpad/backends-47.txt" | grep . | paste -sd,)
N=$(echo "$LIST" | tr ',' '\n' | grep -c .)
[ "$N" = 47 ] || { echo "FATAL: $N triples, want 47"; exit 9; }

echo "sha=$SHA anchor=$A triples=$N src=$SRC build=$B"
export WANT_ANCHOR=$A
export MT_MAKEFLAGS=${MT_MAKEFLAGS:--j8}
# `c,lto' is mt-conf.sh's own default and is what the four-target board was
# measured with, so the compiler under test is comparable with it.  The
# observable for this task (`gcc.target/aarch64/mv*') is C.  Note the
# consequence explicitly rather than leaving it silent: `ada/', `d/' and
# `jit/' are NOT compiled by this build, so the three exclusion-table edits in
# those front ends are unmeasured here -- they are the same edit as the
# c-family one, and saying so is not the same as having built them.
export MT_LANGUAGES=${MT_LANGUAGES:-c,lto}
SRC=$SRC sh "$W/scratchpad/mt-conf.sh" "$B" "$LIST"
SRC=$SRC sh "$W/scratchpad/mt-build.sh" "$B" all-gcc all-gcc
