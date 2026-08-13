#!/bin/sh
# Lay out the #78 working directory: inputs and the lto-wrapper shim.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a4f7386f72ea30a8c/scratchpad
WORK=${WORK:-/tmp/t78}
mkdir -p "$WORK/shim" || exit 9
printf 'extern int helper (void);\nint main (void)\n{\n  return helper () - 1;\n}\n' > "$WORK/a.c"
printf 'int helper (void);\nint helper (void)\n{\n  return 1;\n}\n' > "$WORK/b.c"
cp "$S/t78-shim.sh" "$WORK/shim/lto-wrapper" || exit 9
chmod +x "$WORK/shim/lto-wrapper"
ls -l "$WORK"
