#!/bin/sh
# agent-a018835bbcfad2e28-autoinc.sh -- is the auto-inc-dec pass DOING anything?
#
# The claim under test: in the multi-target compiler every
# HAVE_{PRE,POST}_{INCREMENT,DECREMENT,MODIFY_DISP} reads 0, because the shared
# tm.h is i386's and i386 defines none of them, so `auto_inc_dec' finds no
# addressing form to use on ANY base.
#
# "The dump is empty" and "the dump was never produced" are the same absent
# file, so both arms are asserted by name.  And the STOCK arm is the
# non-vacuity control: if stock also shows zero, the input is wrong, not the
# compiler.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
O=${O:-/tmp/w-a018835bbcfad2e28}/autoinc
BM=${BM:-/tmp/b-a018835bbcfad2e28}
BS=${BS:-/tmp/b-stock-agent-ab1900d5279ba137f-riscv64}
VER=$(cat "$BM/gcc/BASE-VER" 2>/dev/null || basename "$(ls -d "$BM"/lib/gcc/*/ | head -1)")
CFG=$BM/lib/gcc/$VER/riscv64-unknown-linux-gnu/specs-config
F=$W/gcc/testsuite/gcc.target/riscv/xtheadmemidx-modify.c
I=$W/gcc/testsuite/gcc.target/riscv
FLAGS="-O2 -march=rv64gc_xtheadmemidx -mabi=lp64d -I$I"

rm -rf "$O"; mkdir -p "$O/stock" "$O/mt"

( cd "$O/stock" && "$BS/gcc/xgcc" -B"$BS/gcc/" -S $FLAGS \
    -fdump-rtl-auto_inc_dec -o out.s "$F" ) > "$O/stock.err" 2>&1
( cd "$O/mt" && "$BM/gcc/xgcc" -B"$BM/gcc/" -ftarget-config="$CFG" -S $FLAGS \
    -fdump-rtl-auto_inc_dec -o out.s "$F" ) > "$O/mt.err" 2>&1

for s in stock mt; do
  d=$(ls "$O/$s"/*auto_inc_dec* 2>/dev/null | head -1)
  if [ -z "$d" ]; then
    echo "$s: NO auto_inc_dec DUMP PRODUCED -- the pass did not run at all"
    sed -n '1,5p' "$O/$s.err"
    continue
  fi
  echo "$s: dump $(basename "$d")  $(wc -l < "$d") lines"
  echo "    post_inc/post_dec/pre_inc/pre_dec rtx in dump: $(grep -cE '\(post_(inc|dec|modify)|\(pre_(inc|dec|modify)' "$d")"
  echo "    th\\. insns in .s:                            $(grep -c 'th\.' "$O/$s/out.s")"
done
