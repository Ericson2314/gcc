#!/bin/sh
# agent-a018835bbcfad2e28-align.sh -- BOARD ITEM 7, reproduced in one command,
# and it is not what the board files it as.
#
# The board records `gcc.c-torture/execute/align-3.c' as 20 KILLED, "the
# assembler asked for 2^63 bytes ... the compiler emitting a nonsense alignment
# operand", and ranks it as a cheap riscv64 wrong-VALUE bug.
#
# The operand is not nonsense and the bug is not riscv64's.  `align-3.c' asks
# for `__attribute__((aligned(256)))', i.e. LOG = 8:
#
#   stock       .align<TAB>8      riscv.h:1122   "\t.align\t%d",  LOG
#   multi-target.align<SPACE>256  i386/att.h:60  "\t.align %d",   1 << LOG
#
# riscv's `.align N' means 2^N bytes, so `256' is read as a request for 2^256
# and the assembler's arithmetic saturates -- which is where
# `9223372036854841454' comes from.  The emitted line is character-for-character
# i386's macro, down to the space where riscv uses a tab, because the shared
# `tm.h' every target-independent TU is compiled against includes only the i386
# header chain.  `varasm.cc:2163' is the site.
#
# THE SAME DIFF SHOWS A SECOND, INDEPENDENT ALIGNMENT LEAK: the `.align 1'
# before `main' is gone.  That one is not ASM_OUTPUT_ALIGN.  `varasm.cc:2155'
# computes `align = floor_log2 (align / BITS_PER_UNIT)' and emits nothing when
# it is 0; `i386.h:823' is `FUNCTION_BOUNDARY 8' (bits) against riscv's 32/16,
# so the shared code computes floor_log2 (1) = 0 and EVERY function on EVERY
# base loses its alignment directive.  Neither macro is in
# `multi-target-macros.h'; both are in -leakcensus.sh's LEAK-PRIMARY list.
#
# usage: [BM=<mt builddir>] align.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
W=$(cd "$S/.." && pwd)
O=${O:-/tmp/w-a018835bbcfad2e28}
F=$W/gcc/testsuite/gcc.c-torture/execute/align-3.c

BM=${BM:-/tmp/b-a018835bbcfad2e28} sh "$S/agent-a018835bbcfad2e28-sdiff.sh" "$F" -O0 > "$O/align3.out" 2>&1
sed -n '1,40p' "$O/align3.out"

echo
echo "-- the two arms, by name:"
for s in stock mt; do
  printf '   %-6s %s\n' "$s" "$(grep -m1 '\.align' "$O/align-3.$s.s" | cat -A | sed 's/\$$//')"
done

echo
echo "-- ARMS (each must hold, or this script is not measuring what it says):"
rc=0
grep -qP '\.align\t8$'  "$O/align-3.stock.s" || { echo "   FAIL stock is not '.align<TAB>8'"; rc=1; }
grep -q  '\.align 256$' "$O/align-3.mt.s"    || { echo "   FAIL mt is not '.align<SPACE>256'"; rc=1; }
# 1 << 8 == 256: the arithmetic that identifies att.h rather than riscv.h
[ "$((1 << 8))" = 256 ] || { echo "   FAIL the 1<<LOG identity"; rc=1; }
# the SECOND leak: stock aligns `main', mt does not
a=$(grep -c '\.align' "$O/align-3.stock.s"); b=$(grep -c '\.align' "$O/align-3.mt.s")
echo "   .align directives: stock $a, mt $b"
[ "$a" -gt "$b" ] || { echo "   FAIL expected stock to emit MORE .align than mt"; rc=1; }
[ "$rc" = 0 ] && echo "   all arms hold"
echo "ALIGN rc=$rc"
exit $rc
