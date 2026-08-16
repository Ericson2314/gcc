#!/bin/sh
# agent-a018835bbcfad2e28-sdiff.sh -- both-sided .s for ONE riscv64 testcase.
#
# The instrument the board says is missing for the scan-assembler residual:
# same source, same flags, stock cc1 vs multi-target cc1, diff the text.
#
# BOTH ARMS MUST PRODUCE A NON-EMPTY .s.  "the compiler failed" and "the
# compiler emitted different code" are the two readings of a scan-assembler
# FAIL and they are not the same finding; an empty or missing .s is refused
# here by name rather than diffed as if it were code.
#
# usage: [BM=<mt builddir>] [BS=<stock builddir>] sdiff.sh <testfile> <flags...>
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
O=${O:-/tmp/w-a018835bbcfad2e28}
BM=${BM:-/tmp/b-a018835bbcfad2e28}
BS=${BS:-/tmp/b-stock-agent-ab1900d5279ba137f-riscv64}
VER=$(cat "$BM/gcc/BASE-VER" 2>/dev/null || basename "$(ls -d "$BM"/lib/gcc/*/ | head -1)")
CFG=$BM/lib/gcc/$VER/riscv64-unknown-linux-gnu/specs-config
mkdir -p "$O"

F=${1:?testfile}; shift
N=$(basename "$F" .c)
[ -f "$CFG" ] || { echo "FATAL: no specs-config at $CFG"; exit 9; }

"$BS/gcc/xgcc" -B"$BS/gcc/" -S "$@" -o "$O/$N.stock.s" "$F" > "$O/$N.stock.err" 2>&1
rcs=$?
"$BM/gcc/xgcc" -B"$BM/gcc/" -ftarget-config="$CFG" -S "$@" -o "$O/$N.mt.s" "$F" > "$O/$N.mt.err" 2>&1
rcm=$?
echo "== $N  stock rc=$rcs  mt rc=$rcm"
for s in stock mt; do
  f=$O/$N.$s.s
  if [ ! -s "$f" ]; then
    echo "FATAL: $s produced no assembly -- this is a COMPILE failure, not a codegen diff"
    sed -n '1,10p' "$O/$N.$s.err"; exit 9
  fi
  # non-vacuity: assembly, not just a header
  ni=$(grep -cE '^\s+[a-z]' "$f")
  echo "   $s: $(wc -l < "$f") lines, $ni insn-ish"
  [ "$ni" -gt 0 ] || { echo "FATAL: $s .s has no instructions"; exit 9; }
done
echo "-- diff stock vs mt (unified, first 120):"
diff -u "$O/$N.stock.s" "$O/$N.mt.s" | sed -n '1,120p'
echo "-- diff line count: $(diff "$O/$N.stock.s" "$O/$N.mt.s" | grep -c '^[<>]')"
