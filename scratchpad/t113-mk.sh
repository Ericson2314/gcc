#!/bin/sh
# Derive task #113's harness from #112's: repoint SRC at THIS worktree and the
# build dir at /tmp/b113.  PRINCIPLES 5: build your own build dir; a file you
# did not write in a shared one is not a fixture.
#
# TRAP RECORDED BY #112 AND RE-CHECKED HERE: the sed pattern must rewrite the
# INVOCATIONS (`t112-build.sh') as well as the paths, or the derived driver
# builds into someone else's dir with someone else's SRC.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098
cd "$W/scratchpad" || exit 9
OLD=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315
for f in build run ts reconf-gcc go armD2 armE ipa-diag; do
  s=t112-$f.sh; d=t113-$f.sh
  [ -f "$s" ] || { echo "no $s (skipped)"; continue; }
  sed -e "s#$OLD#$W#g" -e 's#/tmp/b112#/tmp/b113#g' \
      -e 's#/tmp/t112#/tmp/t113#g' -e 's#t112-#t113-#g' "$s" > "$d"
  chmod +x "$d"
  echo "made $d"
done
echo "--- residual references to #112 paths (must be empty):"
grep -n 'agent-aa0b\|b112\|t112' t113-*.sh
echo "--- grep rc=$? (1 means clean)"
