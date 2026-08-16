#!/bin/sh
# agent-a018835bbcfad2e28-predict.sh -- for each of riscv64's top debt FILES,
# is the multi-target compiler's assembly now identical to stock's?
#
# WHY PREDICT AT ALL WHEN A SUITE RUN IS RUNNING.  Because the two answer
# different questions and the cheap one is the one that attributes.  A
# `scan-assembler' FAIL says a pattern was not found; it does not say whether
# the emitted code differs from stock at all, and a file can go from FAIL to
# PASS for a reason unrelated to the change under test.  "The emitted text is
# now byte-identical to stock's" is a stronger statement than "the test
# passes", and it is one compilation per file.
#
# IT IS A PREDICTION AND IS LABELLED ONE.  The options here come from the
# file's own `dg-options' line, which is NOT what `riscv.exp' runs: that
# harness multiplies each file by several option sets, which is why 22
# directives in `xtheadmemidx-modify.c' score 88 results.  So IDENTICAL here
# predicts those results pass and does not prove it; the suite is the proof.
# Files whose options cannot be read are reported as SKIP by name and never
# silently dropped -- a shrinking denominator is how this kind of script
# flatters itself.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
O=${O:-/tmp/w-a018835bbcfad2e28}/predict
MT=${MT:?multi-target build dir}
ST=${ST:-/tmp/b-stock-agent-ab1900d5279ba137f-riscv64}
LIST=${1:?file listing "count path" lines}
N=${2:-25}
mkdir -p "$O"
VER=$(basename "$(ls -d "$MT"/lib/gcc/*/ | head -1)")
CFG=$MT/lib/gcc/$VER/riscv64-unknown-linux-gnu/specs-config
[ -f "$CFG" ] || { echo "FATAL: no $CFG"; exit 9; }

same=0; diff_=0; skip=0; sameres=0; diffres=0
head -n "$N" "$LIST" | while read -r cnt f; do
  src=$W/gcc/testsuite/$f
  [ -f "$src" ] || { echo "SKIP    $cnt $f (no such file)"; continue; }
  # the file's own dg-options for rv64, else a plain default
  opt=$(sed -n 's/.*dg-options "\([^"]*\)".*rv64.*/\1/p' "$src" | head -1)
  [ -n "$opt" ] || opt=$(sed -n 's/.*dg-options "\([^"]*\)".*/\1/p' "$src" | head -1)
  [ -n "$opt" ] || opt="-O2"
  case "$opt" in *-march=*) ;; *) opt="$opt -march=rv64gc -mabi=lp64d" ;; esac
  case "$opt" in *-O*) ;; *) opt="-O2 $opt" ;; esac
  I=$(dirname "$src")

  "$ST/gcc/xgcc" -B"$ST/gcc/" -S $opt -I"$I" -o "$O/s.s" "$src" > "$O/s.err" 2>&1
  rs=$?
  "$MT/gcc/xgcc" -B"$MT/gcc/" -ftarget-config="$CFG" -S $opt -I"$I" \
      -o "$O/m.s" "$src" > "$O/m.err" 2>&1
  rm_=$?
  if [ "$rs" != 0 ] || [ ! -s "$O/s.s" ]; then
    echo "SKIP    $cnt $f (stock did not compile with '$opt')"; continue
  fi
  if [ "$rm_" != 0 ] || [ ! -s "$O/m.s" ]; then
    echo "MTFAIL  $cnt $f (multi-target did not compile)"; continue
  fi
  if diff -q <(grep -v '^\s*\.file' "$O/s.s") <(grep -v '^\s*\.file' "$O/m.s") > /dev/null; then
    echo "SAME    $cnt $f"
  else
    d=$(diff <(grep -v '^\s*\.file' "$O/s.s") <(grep -v '^\s*\.file' "$O/m.s") | grep -c '^[<>]')
    echo "DIFFER  $cnt $f ($d lines)"
  fi
done
