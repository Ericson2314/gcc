#!/bin/sh
# gcc.dg/lto debt per target, at depth 2, so the "53 identically on three
# targets" claim from the previous board can be checked rather than inherited.
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a992b7e5fa4ffaaa7/scratchpad
L=/tmp/board-agent-a992b7e5fa4ffaaa7
for spec in \
 "aarch64-unknown-linux-gnu|/tmp/b-stock-agent-a3464debf6893de84-aarch64/gcc/testsuite.aarch64-unknown-linux-gnu/gcc/gcc.sum" \
 "riscv64-unknown-linux-gnu|/tmp/b-stock-agent-ab1900d5279ba137f-riscv64/gcc/testsuite.riscv64-unknown-linux-gnu/gcc/gcc.sum" \
 "s390x-ibm-linux-gnu|/tmp/b-stock-agent-a3464debf6893de84-s390x/gcc/testsuite.s390x-ibm-linux-gnu/gcc/gcc.sum" \
 "x86_64-pc-linux-gnu|/tmp/b-stock-agent-ab1900d5279ba137f-x86_64/gcc/testsuite.x86_64-pc-linux-gnu/gcc/gcc.sum" ; do
  T=${spec%%|*}; ST=${spec#*|}
  n=$(sh "$S/mt-debt-rank.sh" "$L/$T.sum" "$ST" 2 2000 2>/dev/null \
      | awk '$1 ~ /^gcc\.dg\/lto/ { s += $2 } END { print s+0 }')
  printf '%-28s gcc.dg/lto debt %s\n' "$T" "$n"
done
