#!/bin/sh
# agent-a95a42fd940ce4d8e-insn.sh -- print THE UNRECOGNIZABLE INSN for each of
# the six, and the SIZE the shared code gave the nonlocal-goto save area on ALL
# ten targets.
#
# This is the arm that separates the two fixes the ICE cannot tell apart.  The
# brief's rule: if the RTL differs from a stock cross the bug is upstream of
# `recog'; if the RTL is identical and only matching fails it is in the pattern
# conditions or the numbering.  Here the RTL is visibly WRONG on its face -- a
# 16-byte load into a 4-byte stack pointer is not something any back end's
# `.md' could or should match -- so no stock control is needed to establish
# that the defect is UPSTREAM of recog.  A control would tell us what the right
# mode is; `defaults.h:1494' already states it (`Pmode').
#
# THE CONTROL SIDE IS THE POINT, AND IT IS NOT "THE CONTROLS PASS".  x86_64,
# aarch64, riscv64 and s390x do not ICE, and that is NOT evidence they got the
# right answer: they read the SAME leaked TImode and merely happen to have a
# 16-byte move.  So the `S<n>' operand size is printed for all ten from the
# expand dump, and a back end that "passes" while showing S16 is carrying the
# defect silently.  Same shape as the 8 quiet back ends under `avr-fuse-add'.
set -u
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/savearea}
echo "== the unrecognizable insn, per back end"
for t in alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi \
         avr-unknown-elf mips64-unknown-elf or1k-unknown-elf; do
  printf '\n-- %s\n' "$t"
  sed -n '/unrecognizable insn/,/^during RTL pass/p' "$O/$t/err" \
    | grep -E '^\(insn|^ *\(' | head -4
done
echo
echo "== the SP-restore insn in the expand dump, ALL TEN (control side)"
printf '%-30s %s\n' TARGET 'SP <- save area  (S<n> = bytes read)'
for t in alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi \
         avr-unknown-elf mips64-unknown-elf or1k-unknown-elf \
         x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  d=$(ls "$O/$t"/*.expand 2>/dev/null | head -1)
  if [ -z "$d" ]; then printf '%-30s %s\n' "$t" NO-EXPAND-DUMP; continue; fi
  # the set whose destination is the stack pointer and whose source is a MEM
  line=$(grep -oE '\(set \(reg/f:[A-Z]+ [0-9]+ [a-z0-9]+\)[^)]*$|\(mem:[A-Z]+ [^)]*\[0 *S[0-9]+' "$d" \
         | grep -oE 'mem:[A-Z]+ .*S[0-9]+' | head -1)
  [ -n "$line" ] || line=$(grep -oE 'mem:[A-Z]+[^]]*S[0-9]+ A[0-9]+' "$d" | head -1)
  [ -n "$line" ] || line='(no MEM save-area load found)'
  printf '%-30s %s\n' "$t" "$line"
done
