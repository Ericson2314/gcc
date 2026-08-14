#!/bin/sh
# Syntax-check ONE source from the LIVE worktree using the exact compile
# command a completed build used for it, with the snapshot's srcdir `-I's
# swapped for the worktree's.  A cheap arm before committing to a full
# rebuild; it is NOT a substitute for one -- generated headers still come from
# the build dir, so a change that alters a generated file is invisible here.
#
# usage: ta76-syntax.sh <builddir> <object name, e.g. target-cumargs-arm.o> <src.cc>
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}; OBJ=${2:?object}; SRCFILE=${3:?source}
case "$D" in
  */b-a76e996f6ef44dca5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
SNAP=$(cat "$D/MY-SRC")
WT=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a76e996f6ef44dca5
cmd=$(grep -m1 -- "-o $OBJ " "$D/make-top.out")
[ -n "$cmd" ] || { echo "FATAL: no compile line for $OBJ in $D/make-top.out"; exit 9; }
# Drop -o/-MT/-MMD/-MP/-MF and the source, add -fsyntax-only, repoint srcdir.
cmd=$(printf '%s' "$cmd" \
      | sed -e "s|-o $OBJ||" -e 's|-MT [^ ]*||' -e 's|-MMD||' -e 's|-MP||' \
            -e 's|-MF [^ ]*||' -e "s|$SNAP/gcc/[A-Za-z0-9_./-]*\.cc||g" \
            -e "s|$SNAP|$WT|g" -e 's|\\ *$||')
echo "checking $SRCFILE against $OBJ's flags"
{ echo "cd $D/gcc"
  printf '%s -fsyntax-only %s\n' "$cmd" "$WT/gcc/$SRCFILE"
} > "$D/syntax.sh"
sh "$S/eb-shell.sh" "sh $D/syntax.sh" 2>&1 \
  | grep -E 'error|Error' | head -20
echo "(no 'error' lines above means it compiles)"
