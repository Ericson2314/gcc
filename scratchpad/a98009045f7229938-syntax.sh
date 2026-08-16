#!/bin/sh
# Syntax-check THIS WORKTREE's edited shared sources against an EXISTING build
# dir's generated headers, by reusing that build's own compile line.
#
# WHY.  A 47-base cold build costs an hour or more under load, and a typo in a
# six-file change costs the whole of it.  This is the cheap arm: `-fsyntax-only`
# with the real `-I` set and the real `-D` set, taken from the build log rather
# than reconstructed -- a reconstructed flag set answers a different question
# than the build does, which is the failure this project keeps meeting.
#
# IT IS A SYNTAX ARM AND NOT A BUILD.  It cannot see a link error, and it reads
# the OTHER build's headers, so it says nothing about whether the change is
# right -- only that it parses where it has to. Stated because a green here is
# exactly the kind of thing that gets quoted as "it builds".
#
# THE SOURCE COMES FROM THE WORKTREE AND THE HEADERS FROM THE BUILD DIR, WHICH
# IS DELIBERATE AND IS THE ONE THING TO GET RIGHT.  The build dir was
# configured from a SNAPSHOT that does not contain the edit; compiling the
# snapshot's copy of the file would parse the UNCHANGED source and pass
# whatever the edit did.  So the file argument is an absolute path into the
# worktree, and ARM 0 asserts the edit is actually in it.
#
# usage: a98009045f7229938-syntax.sh <builddir> <file.cc> [witness-string]
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
B=${1:?build dir}
F=${2:?source file relative to gcc/}
WIT=${3:-mt_has_insn_scheduling}

SRC="$W/gcc/$F"
[ -f "$SRC" ] || { echo "FATAL: no $SRC"; exit 9; }
grep -q "$WIT" "$SRC" || { echo "FATAL: '$WIT' is not in $SRC.  This arm would
have compiled the file WITHOUT the change under test and passed.  Refusing --
that is the null-result-as-a-pass shape, in the arm meant to catch it."; exit 9; }

base=$(basename "$F" .cc)
# The `-o X.o' and the source are NOT adjacent -- `-MT X.o -MMD -MP -MF ...'
# sits between them.  A regex requiring adjacency matched nothing and this
# script said "the build has not reached it yet" about a file the build HAD
# reached, i.e. it failed in the direction that looks like patience.
CMD=$(grep -o "[^ ]*g++[^ ]* .*-o $base\.o .*/gcc/$base\.cc" "$B/all-gcc.log" | tail -1)
[ -n "$CMD" ] || { echo "FATAL: no compile line for $base.o in $B/all-gcc.log --
the build has not reached it yet.  A missing line is NOT a pass."; exit 9; }

# Replace the source path with the worktree's, drop the -o and the dependency
# generation (which would write into the OTHER build's .deps and make its
# objects silently not rebuild -- PRINCIPLES' stale-.Po trap, self-inflicted).
#
# AND THE `-I' SET MUST MOVE TO THE NEW SRCDIR TOO, WHICH IS THE WHOLE POINT
# AND IS EASY TO MISS.  The build dir's `-I' points at the OLD snapshot, so
# swapping only the source file compiles the new `.cc' against the OLD
# headers.  A quoted `#include' searches the INCLUDING FILE's directory first,
# so no amount of extra `-I' overrides it: the generated `insn-attr.h' ends
# with `#include "multi-target-attr.h"', which is found in the old snapshot and
# includes the old snapshot's `target-automata.h'.  Measured, by the arm
# reporting `mt_has_insn_scheduling was not declared' four times against a
# tree where it IS declared -- a FALSE RED, which is at least the safe
# direction, and the false GREEN is the same mechanism with the change on the
# other side.  NEWSRC is required rather than defaulted for that reason.
# NOT `${NEWSRC:?long message}': the word after `:?' is parsed for QUOTES, so
# an apostrophe in it ("the OLD snapshot's headers") opens a string that never
# closes and the whole script dies with `unexpected EOF' pointing at a line
# twenty further down.  PRINCIPLES records the same character doing the same
# thing to a generated makefile.  An explicit test takes a plain double-quoted
# string and has no such rule.
NEWSRC=${NEWSRC:-}
[ -n "$NEWSRC" ] || { echo "FATAL: set NEWSRC to a snapshot of the tree under
test.  Without it this arm compiles the new source against the OLD snapshot
headers and reports on a file the change is not in."; exit 9; }
[ -f "$NEWSRC/SNAP-SHA" ] || { echo "FATAL: $NEWSRC has no SNAP-SHA"; exit 9; }
OLDSRC=$(cat "$B/MY-SRC")
NEW=$(printf '%s' "$CMD" \
  | sed "s#-o $base\.o#-fsyntax-only#" \
  | sed "s#-MT $base\.o##; s#-MMD -MP##; s#-MF [^ ]*##" \
  | sed "s#$OLDSRC#$NEWSRC#g" \
  | sed "s#[^ ]*/gcc/$base\.cc#$SRC#")
# Non-vacuity on the swap itself: if OLDSRC never appeared, the sed above did
# nothing and the arm is silently back to testing the old headers.
case "$CMD" in *"$OLDSRC"*) ;; *) echo "FATAL: the recorded compile line does
not mention $OLDSRC, so the srcdir swap did nothing.  Refusing."; exit 9 ;;
esac
# INSIDE THE DEV SHELL.  `g++' is not on PATH outside it, and `command not
# found' from a compiler reads as a compile failure -- PRINCIPLES' "a missing
# tool looks exactly like a zero result", here in the loud direction rather
# than the quiet one, which is only luck.
cd "$B/gcc"
if sh "$W/scratchpad/eb-shell.sh" "cd $B/gcc && $NEW"; then
  echo "SYNTAX OK   $F   (witness '$WIT' present)"
else
  echo "SYNTAX FAIL $F"; exit 1
fi
