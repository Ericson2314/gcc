#!/bin/sh
# Derive task #112's harness from #111's: repoint SRC at THIS worktree and the
# build dir at /tmp/b112.  PRINCIPLES 5: build your own build dir; a file you
# did not write in a shared one is not a fixture.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315
cd "$W/scratchpad" || exit 9
OLD=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a583ac0157ff44074
for f in build run ts reconf-gcc go armD2 armD-verify guards insn-guards; do
  s=t111-$f.sh; d=t112-$f.sh
  [ -f "$s" ] || { echo "no $s (skipped)"; continue; }
  sed -e "s#$OLD#$W#g" -e 's#/tmp/b111#/tmp/b112#g' \
      -e 's#/tmp/t111#/tmp/t112#g' -e 's#/tmp/t106#/tmp/t112#g' "$s" > "$d"
  chmod +x "$d"
  echo "made $d"
done
echo "--- residual references to #111 paths (must be empty):"
grep -n 'agent-a583\|b111\|t111' t112-*.sh
echo "--- rc=$?"
