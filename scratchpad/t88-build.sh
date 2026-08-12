#!/bin/sh
# t88-build.sh <builddir> <logbase> [target...]
# Scores nothing; it only runs make and records rc.  The caller checks the
# ARTEFACT -- a generator that fails and exits 0 has happened on this branch.
set -u
D=$1; shift
L=$1; shift
/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03/scratchpad/t88-shell.sh \
  "cd $D && make -j8 $*" > "$L.out" 2> "$L.err"
echo "rc=$? $L" >> "$L.rc"
