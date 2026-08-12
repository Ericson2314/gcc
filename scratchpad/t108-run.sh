#!/bin/sh
# Task #106: run cc1 for BOTH targets and score on rc.
#
# Scoring, per the brief: rc=4 is an ICE, rc=139 a raw SIGSEGV, rc=0 success.
# `[ -s out.s ]' scores GREEN while cc1 exits 4 (it writes ~30 bytes then dies),
# so the .s size is REPORTED but the verdict is the exit status.
set -u
D=${D:-/tmp/b108}
IN=${IN:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7d5fb84bdd2264ac/scratchpad/big.c}
OUT=${OUT:-/tmp/t108-out}
[ -s "$IN" ] || { echo "FATAL: empty/missing input $IN"; exit 9; }
IN=$(readlink -f -- "$IN")
mkdir -p "$OUT"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 at $D/gcc/cc1"; exit 9; }
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  cfg="specs-$t-config"
  [ -s "$D/gcc/$cfg" ] || { echo "FATAL: no $cfg -- run t106-ts.sh"; exit 9; }
  (cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$cfg" \
      "$IN" -o "$OUT/$t.s") > "$OUT/$t.log" 2>&1
  rc=$?
  case $rc in
    0)   v="rc=0 SUCCESS" ;;
    4)   v="rc=4 ICE" ;;
    139) v="rc=139 RAW SIGSEGV" ;;
    *)   v="rc=$rc OTHER" ;;
  esac
  sz=0; [ -f "$OUT/$t.s" ] && sz=$(wc -c < "$OUT/$t.s")
  ln=0; [ -f "$OUT/$t.s" ] && ln=$(wc -l < "$OUT/$t.s")
  echo "$t: $v   .s=${sz}bytes/${ln}lines"
  # The frame of the failure, if any.
  grep -m3 -E "internal compiler error|in [a-z0-9_]+, at|0x[0-9a-f]+ " "$OUT/$t.log" \
    | sed 's/^/      /'
done
