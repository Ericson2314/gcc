#!/bin/sh
# agent-acf1cacfef7c17c69-verify.sh -- the acceptance set for this task, in one
# command, run against ONE build dir that must name the tree it came from.
#
# ARMS, in the order the brief puts them:
#   bars     x86_64 -O2 big.c;  specs-config line count
#   4        TARGET_HAS_FMV_TARGET_ATTRIBUTE   (measurable: mv-1.c + control)
#   1        STACK_POINTER_OFFSET              (s390x, diff vs genuine stock)
#   2        the trampoline pair               (aarch64, diff vs genuine stock)
#   3        __builtin_eh_return               (four targets vs genuine stock)
#
# EVERY ARM IS BOTH-SIDED OR REFUSES.  Arms 1-3 diff against the stock build
# dirs the board's debt is scored against; arm 4's control is x86_64, which
# reads the floor's 1 as its OWN answer and therefore must not move.
#
# NOTHING HERE DEFAULTS THE BUILD DIR.  A default is how 485 scripts on this
# branch came to name someone else's worktree.
#
# usage: agent-acf1cacfef7c17c69-verify.sh <mt-builddir>
set -u
B=${1:?mt build dir}
W=$(cd "$(dirname "$0")" && pwd)

[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
[ -r "$B/MY-SRC" ]   || { echo "FATAL: no $B/MY-SRC"; exit 9; }
SRC=$(cat "$B/MY-SRC")
echo "================================================================"
echo "build   $B"
echo "srcdir  $SRC"
echo "sha     $(cat "$SRC/SNAP-SHA" 2>/dev/null || echo '(not a snapshot)')"
echo "anchor  $(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")"
echo "cc1     $(ls -l "$B/gcc/cc1" 2>/dev/null | awk '{print $5}') bytes"
echo "================================================================"

rc=0
run () {  # run <label> <cmd...>
  lab=$1; shift
  echo; echo "---- $lab ----------------------------------------------------"
  if "$@"; then echo "[$lab: arm rc=0]"; else
    echo "[$lab: arm rc=$? -- READ IT, do not summarise it]"; rc=1
  fi
}

echo; echo "---- BARS -------------------------------------------------------"
sh "$W/mt-bars.sh" "$B" || rc=1
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         s390x-ibm-linux-gnu riscv64-unknown-linux-gnu; do
  f="$B/lib/gcc/17.0.0/$T/specs-config"
  if [ -r "$f" ]; then
    printf 'specs-config %-28s wc -l %s   grep -c . %s\n' \
      "$T" "$(wc -l < "$f")" "$(grep -c . "$f")"
  else
    printf 'specs-config %-28s ABSENT\n' "$T"
  fi
done

run "ITEM 4  TARGET_HAS_FMV_TARGET_ATTRIBUTE" \
  sh "$W/agent-acf1cacfef7c17c69-fmv.sh" "$B"

run "ITEM 1  STACK_POINTER_OFFSET (s390x)" \
  sh "$W/agent-a992b7e5fa4ffaaa7-spo.sh" "$B"

run "ITEM 2  trampoline section + alignment (aarch64)" \
  sh "$W/agent-a992b7e5fa4ffaaa7-tramp.sh" "$B"

run "ITEM 3  __builtin_eh_return (four targets)" \
  sh "$W/agent-a992b7e5fa4ffaaa7-ehreturn.sh" "$B"

echo
echo "================================================================"
[ "$rc" = 0 ] && echo "ALL ARMS PASSED" || echo "SOME ARM FAILED -- read it, do not summarise it"
exit "$rc"
