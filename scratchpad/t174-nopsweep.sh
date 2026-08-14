#!/bin/sh
cd /tmp/snap-ab0e/gcc/config || exit 9
for d in */; do
  b=${d%/}
  n=$(grep -rlE 'define_(insn|expand)[^"]*"nop"' "$d" 2>/dev/null | head -1)
  k=$(grep -rlE 'define_(insn|expand)[^"]*"blockage"' "$d" 2>/dev/null | head -1)
  echo "$b nop=${n:+Y} blockage=${k:+Y}"
done
