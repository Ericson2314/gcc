#!/bin/sh
# agent-a95a42fd940ce4d8e-finish.sh -- wait for the POST build and the PRE
# score, then run every verification arm in order and leave one readable log.
#
# Detached because the agent harness culls background commands, and a culled
# run leaves a stale stamp beside a partial artefact -- the shape PRINCIPLES
# warns about.  Each arm writes its own file so a truncated tail cannot be
# mistaken for a completed arm.
set -u
S=$(cd "$(dirname "$0")" && pwd)
PRE=/tmp/b-a95a42fd940ce4d8e
POST=/tmp/b-a95a42fd940ce4d8e-post
O=/tmp/w-agent-a95a42fd940ce4d8e/FINISH
mkdir -p "$O"

echo "== waiting for POST build"
while ! grep -q 'POST-BUILD-DONE' /tmp/post-a95.log 2>/dev/null; do
  if grep -qE '^make.*Error' /tmp/post-a95.log 2>/dev/null; then
    echo "POST BUILD FAILED"; grep -m5 'error:' "$POST/all-gcc.err"; exit 9
  fi
  sleep 20
done
echo "POST build done rc=$(cat "$POST/gcc/all-gcc.rc")"
echo "  error: count $(grep -c 'error:' "$POST/all-gcc.err")"
ls -la "$POST/gcc/cc1"

echo
echo "== POST specs for the ten targets"
B=$POST TOOLS=/tmp/tools-agent-a95a42fd940ce4d8e sh "$S/a7ee6ca7c923e4a58-specsN.sh" \
  alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi avr-unknown-elf \
  mips64-unknown-elf or1k-unknown-elf x86_64-pc-linux-gnu \
  aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu \
  > "$O/specs.out" 2>&1
tail -16 "$O/specs.out"

echo
echo "== ARM 1: the x86_64 codegen bar on the POST compiler"
WANT_ANCHOR=52 sh "$S/mt-bars.sh" "$POST" > "$O/bars.out" 2>&1
head -4 "$O/bars.out"

echo
echo "== ARM 2: one-line census, POST (nobody must die on its first input)"
sh "$S/a7ee6ca7c923e4a58-onelinecensus.sh" "$POST" > "$O/olc.out" 2>&1
tail -3 "$O/olc.out"

echo
echo "== ARM 3: both-sided save-area mode, ten targets, PRE vs POST"
PRE=$PRE POST=$POST sh "$S/agent-a95a42fd940ce4d8e-bothsided.sh" \
  > "$O/bothsided.out" 2>&1
cat "$O/bothsided.out"

echo
echo "== ARM 4: targeted by-name verification, the 14 tests x 5 levels"
PRE=$PRE POST=$POST sh "$S/agent-a95a42fd940ce4d8e-verify.sh" \
  > "$O/verify.out" 2>&1
cat "$O/verify.out"

echo
echo "== waiting for the PRE full score"
while ! grep -q 'targets with a non-empty' /tmp/pre-score-a95.log 2>/dev/null; do
  sleep 60
done
cat /tmp/pre-score-a95.log

echo
echo "== POST full score, gcc.c-torture/compile, six back ends"
WANT_ANCHOR=52 B=$POST OUT=/tmp/w-agent-a95a42fd940ce4d8e/POST \
  sh "$S/agent-a95a42fd940ce4d8e-score6.sh" > "$O/post-score.out" 2>&1
cat "$O/post-score.out"

echo
echo "== ARM 5: BY NAME, per back end (mt-namediff.sh), never column totals"
for t in alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi \
         avr-unknown-elf mips64-unknown-elf or1k-unknown-elf; do
  a=/tmp/w-agent-a95a42fd940ce4d8e/PRE/$t.sum
  b=/tmp/w-agent-a95a42fd940ce4d8e/POST/$t.sum
  echo "---- $t"
  if [ -s "$a" ] && [ -s "$b" ]; then
    sh "$S/mt-namediff.sh" "$a" "$b" "$t" > "$O/namediff.$t" 2>&1
    tail -30 "$O/namediff.$t"
  else
    echo "MISSING a .sum -- not a comparison (PRE=$( [ -s "$a" ] && echo ok || echo no) POST=$( [ -s "$b" ] && echo ok || echo no))"
  fi
done

echo
echo "== ARM 6: the site itself, by FAIL row, per back end"
printf '%-28s %6s %6s\n' TARGET PRE POST
tot_a=0; tot_b=0
for t in alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi \
         avr-unknown-elf mips64-unknown-elf or1k-unknown-elf; do
  a=$(grep -c '^FAIL.*recog\.cc:2892' /tmp/w-agent-a95a42fd940ce4d8e/PRE/$t.log 2>/dev/null || echo 0)
  b=$(grep -c '^FAIL.*recog\.cc:2892' /tmp/w-agent-a95a42fd940ce4d8e/POST/$t.log 2>/dev/null || echo 0)
  tot_a=$((tot_a+a)); tot_b=$((tot_b+b))
  printf '%-28s %6s %6s\n' "$t" "$a" "$b"
done
echo "TOTAL recog.cc:2892 FAIL rows   PRE $tot_a   POST $tot_b   (board published 71)"
echo
echo "FINISH-DONE"
