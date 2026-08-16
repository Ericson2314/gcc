#!/bin/sh
# THE CHEAPEST POSSIBLE BOARD: compile ONE trivial function for every target
# that has a specs-config, and record what the compiler says.
#
# WHY THIS EXISTS BESIDE THE REAL BOARD.  A full `.exp' run costs minutes per
# target and cannot be taken for a back end that dies on its first input.  But
# "dies on every input" is itself a result, and it is the one the ranked-cause
# board most needs: a back end whose FIRST compilation segfaults contributes no
# FAIL rows at all, so it is INVISIBLE in a `.sum'-based ranking -- the same
# empty-failure-list ambiguity that a missing assembler and a perfect score
# also produce.
#
# `int f(int x){return x+1;}' needs no header, no libc and no assembler: it is
# `-S' only, so a target with no cross `as' can still be measured HERE even
# though it cannot be scored on the real board.  That is deliberate -- it
# separates "we could not run the tests" from "the compiler cannot compile".
set -u
B=${1:?build dir}
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
SRC=$(cat "$B/MY-SRC")
printf 'int f(int x){return x+1;}\n' > /tmp/olc-$$.c

nok=0; nice=0; nother=0
printf '%-28s %s\n' TARGET RESULT
for d in "$B"/lib/gcc/"$VER"/*/; do
  T=$(basename "$d")
  CFG="$d/specs-config"
  [ -f "$CFG" ] || continue
  out=$("$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" -S -o /dev/null \
        /tmp/olc-$$.c 2>&1)
  if [ -z "$out" ]; then
    printf '%-28s %s\n' "$T" "OK"
    nok=$((nok+1))
  else
    # the FIRST line is the pass name when there is one; the ICE line names the
    # site.  Both are kept -- "during RTL pass: X" is the finding when X
    # belongs to ANOTHER back end.
    pass=$(printf '%s' "$out" | sed -n 's/^during \(.*\)$/\1/p' | head -1)
    ice=$(printf '%s' "$out" | sed -n 's/.*internal compiler error: //p' | head -1)
    err=$(printf '%s' "$out" | sed -n 's/.*error: //p' | head -1)
    if [ -n "$ice" ]; then
      printf '%-28s ICE %s%s\n' "$T" "$ice" "${pass:+   [$pass]}"
      nice=$((nice+1))
    else
      printf '%-28s ERR %s\n' "$T" "${err:-$(printf '%s' "$out" | head -1)}"
      nother=$((nother+1))
    fi
  fi
done
rm -f /tmp/olc-$$.c
echo
echo "OK=$nok ICE=$nice OTHER=$nother"
[ $((nok+nice+nother)) -gt 0 ] || { echo "FATAL: nothing measured"; exit 9; }
