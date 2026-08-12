#!/bin/sh
# Wrapper: run rv-build.sh with targets $2..., logging to $S/$1.{out,err}
set -u
S=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
HERE=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-acd434c7ebbe6ff16
tag=$1; shift
sh "$HERE/scratchpad/rv-build.sh" "$@" > "$S/$tag.out" 2> "$S/$tag.err"
rc=$?
echo "rc=$rc  tag=$tag"
echo "--- stderr tail:"
tail -20 "$S/$tag.err"
exit $rc
