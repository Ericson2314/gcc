#!/bin/sh
# a5764a65f9eec0063 -- compile the minimal SME2 reproducer both sides,
# optionally with RTL dumps, and show both .s files.
# usage: sh a5764a65f9eec0063-min.sh [extra flags...]
set -u
MTD=${MTD:-/tmp/b-a57163422943aaa57-lra}
STD=${STD:-/tmp/b-stock-agent-a3464debf6893de84-aarch64}
W=${W:-/tmp/w-a5764a65f9eec0063}
SRCF=${SRCF:-$W/min.c}
MEMCAP=$(cd "$(dirname "$0")" && pwd)/tb1-memcap.sh
CFG=$MTD/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config

mkdir -p "$W/mt" "$W/st"
OPTS="-O2 -march=armv8-a+sme2 -S"

( cd "$W/mt" && sh "$MEMCAP" 8000000 "$MTD/gcc/xgcc" -B"$MTD/gcc/" \
    -ftarget-config="$CFG" $OPTS "$@" "$SRCF" -o min.s > c.out 2> c.err; echo $? > rc )
( cd "$W/st" && sh "$MEMCAP" 8000000 "$STD/gcc/xgcc" -B"$STD/gcc/" \
    $OPTS "$@" "$SRCF" -o min.s > c.out 2> c.err; echo $? > rc )

for s in mt st; do
  echo "===== $s  rc=$(cat "$W/$s/rc")"
  if [ -s "$W/$s/min.s" ]; then grep -v '^\s*\.' "$W/$s/min.s" | grep -v '^\s*$'
  else echo "  (no .s)"; sed -n '1,10p' "$W/$s/c.err"; fi
done
