#!/bin/sh
# THE aarch64 ARM.  Run the multi-target cc1 with the aarch64 target config and
# see how far it gets.
#
# THIS IS NOT A PASS CRITERION AND MUST NOT BE READ AS ONE.  A `.s' file
# appearing here proves that cc1 no longer ICEs; it does NOT prove the output
# is aarch64 rather than aarch64 mnemonics over the primary's frame layout.
# MACRO-LEAK.md records that generic code still expands STACK_POINTER_REGNUM to
# 7 (aarch64's is 31), FRAME_POINTER_REGNUM to 19 (64), ARG_POINTER_REGNUM to
# 16 (65) and DEFAULT_SIGNED_CHAR to 1 (0), because those are a different
# conversion from this one.  The only evidence that would settle it is a byte
# comparison against a real single-target aarch64 cc1, and there is no such
# reference.  So this script reports WHERE IT STOPS, and nothing more.
set -u
D=${D:-/tmp/b-rv59}
IN=${IN:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-acd434c7ebbe6ff16/scratchpad/big.c}
OUT=${OUT:-/tmp/rv59-a64}

[ -e "$IN" ] || { echo "FATAL: input does not exist: $IN"; exit 9; }
IN=$(readlink -f -- "$IN")
case $IN in /*) ;; *) echo "FATAL: IN did not absolutise"; exit 9;; esac
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 at $D/gcc/cc1"; exit 9; }
for f in specs-aarch64-unknown-linux-gnu-config specs-x86_64-pc-linux-gnu-config; do
  [ -s "$D/gcc/$f" ] || { echo "FATAL: no $f -- target-specs SKIPped it"; exit 9; }
done
rm -rf "$OUT"; mkdir -p "$OUT"

for cfg in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  for O in 0 2; do
    ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O$O \
        -ftarget-config=specs-$cfg-config "$IN" -o "$OUT/$cfg-O$O.s" ) \
      > "$OUT/$cfg-O$O.log" 2>&1
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "$cfg -O$O: rc=$rc  STOPPED"
      sed -n '1,6p' "$OUT/$cfg-O$O.log" | sed 's/^/      /'
    elif [ ! -s "$OUT/$cfg-O$O.s" ]; then
      # rc=0 with no output is not a pass; say so rather than count it.
      echo "$cfg -O$O: rc=0 but produced NO .s -- not a pass"
    else
      echo "$cfg -O$O: rc=0, $(wc -l < "$OUT/$cfg-O$O.s") lines"
    fi
  done
done
