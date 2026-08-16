#!/bin/sh
# Which back ends have a pipeline automaton, read from the GENERATED headers.
#
# WHY NOT `git grep define_insn_reservation gcc/config/<be>'.  A back end's
# `.md' includes others (`sync.md', `mmx.md', a `-generic.md' tuning file), and
# `config.gcc' decides which; a directory-scoped grep answers "does any file
# under this directory mention it", which is a different question and gets
# `mmix' wrong in one direction and shared `.md' fragments wrong in the other.
# PRINCIPLES: "ask what the compiler actually reads, not what the directory
# layout suggests it reads."  `genattr-common' has already answered it, per
# base, in `insn-attr-common-<base>.h'; that file IS the answer.
#
# NON-VACUITY IS THE POINT OF THIS SCRIPT, not a decoration.  "No back end
# lacks a DFA" and "the header glob matched nothing" are the same empty
# output, and this whole family of bug is that confusion.  So it refuses to
# print a verdict unless it saw BOTH a header with the macro and a header
# without one -- i.e. it can only report a number it has demonstrated it can
# report the other value for.
#
# usage: OUT=<builddir>/gcc a98009045f7229938-dfacensus.sh
set -eu
G=${1:-${G:?set G to <builddir>/gcc}}
n=0; with=""; without=""
for f in "$G"/insn-attr-common-*.h; do
  [ -f "$f" ] || continue
  be=$(basename "$f" .h); be=${be#insn-attr-common-}
  n=$((n+1))
  if grep -q '^#define INSN_SCHEDULING$' "$f"; then
    with="$with $be"
  else
    without="$without $be"
  fi
done
[ "$n" -gt 0 ] || { echo "FATAL: no insn-attr-common-*.h under $G -- the glob
matched nothing, which is NOT the same as 'every back end has a DFA'"; exit 9; }
nw=$(echo "$with" | wc -w); nn=$(echo "$without" | wc -w)
[ "$nw" -gt 0 ] || { echo "FATAL: ZERO back ends have INSN_SCHEDULING.  The
grep cannot distinguish that from a changed macro spelling; refusing."; exit 9; }
[ "$nn" -gt 0 ] || { echo "FATAL: ZERO back ends LACK INSN_SCHEDULING, so this
run has not shown the negative arm can fire.  Refusing to report a null result
that is indistinguishable from a broken grep."; exit 9; }
echo "headers read: $n"
echo "HAS a pipeline automaton ($nw):$with"
echo "NO pipeline automaton  ($nn):$without"
