#!/bin/sh
# #140 -- configure a build dir for the BASE_HEADER work, in THIS worktree.
# SRC is derived from $0 (this script's own tree), and the anchor is asserted,
# per PRINCIPLES section 4: a guard that builds somebody else's tree reports a
# clean green against a compiler that is not the one under test.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b140}
# The anchor is 43 here, not the 39 recorded in PRINCIPLES: this change adds
# four MULTI_TARGET_BASE_DEF lines to gcc/Makefile.in.  Asserted by CONTENT as
# well as by count, because a count alone is the weakest evidence available.
grep -q 'MULTI_TARGET_BASE_DEF' "$SRC/gcc/Makefile.in" \
  || { echo "FATAL: $SRC/gcc/Makefile.in has no MULTI_TARGET_BASE_DEF"; exit 9; }
grep -q 'define BASE_HEADER' "$SRC/gcc/multi-target-base.h" \
  || { echo "FATAL: $SRC/gcc/multi-target-base.h has no BASE_HEADER"; exit 9; }
exec sh "$S/t139-conf.sh" "$SRC" "$D" 43
