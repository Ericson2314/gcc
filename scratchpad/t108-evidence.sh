#!/bin/sh
# Task #108 evidence, BOTH-SIDED, at the object level.
#
# `nm -u' WITH A PLAIN-NAME GREP SCORES 0 ON NINE OF TEN of function.o's
# undefined ix86_* references, because they are C++-mangled (PRINCIPLES 7).
# Everything here uses `nm -uC' / `nm -C', and asserts the tool exists and the
# input is non-empty first, because a tool-not-found piped into `grep -c'
# scores 0 in the direction that makes the result look good.
set -u
D=${D:-/tmp/b108}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"

sh_nm () {
  nix-shell -I "nixpkgs=$NP" -p binutils \
    --substituters 'https://cache.nixos.org/' --run "$1"
}

for o in gcc/function.o gcc/target-cumargs-i386.o gcc/target-cumargs-aarch64.o; do
  [ -s "$D/$o" ] || { echo "FATAL: missing/empty $D/$o"; exit 9; }
done

echo "=== 1. function.o: UNDEFINED ix86_* references (nm -uC)"
sh_nm "nm -uC $D/gcc/function.o" > /tmp/t108-fn-u.txt || exit 9
[ -s /tmp/t108-fn-u.txt ] || { echo "FATAL: nm produced no output"; exit 9; }
grep 'ix86_' /tmp/t108-fn-u.txt | sed 's/^/    /'
echo "    COUNT = $(grep -c 'ix86_' /tmp/t108-fn-u.txt)"

echo
echo "=== 1b. THE INSTRUMENT'S BLIND SPOT, SHOWN: plain nm -u on the same file"
sh_nm "nm -u $D/gcc/function.o" > /tmp/t108-fn-u-plain.txt || exit 9
echo "    plain nm -u ix86_ count = $(grep -c 'ix86_' /tmp/t108-fn-u-plain.txt)"

echo
echo "=== 2. BOTH-SIDED: who does each per-base table call?"
for b in i386 aarch64; do
  sh_nm "nm -uC $D/gcc/target-cumargs-$b.o" > /tmp/t108-$b.txt || exit 9
  [ -s /tmp/t108-$b.txt ] || { echo "FATAL: nm empty for $b"; exit 9; }
  echo "  target-cumargs-$b.o:"
  echo "    ix86_*    refs: $(grep -c 'ix86_' /tmp/t108-$b.txt)"
  echo "    aarch64_* refs: $(grep -c 'aarch64_' /tmp/t108-$b.txt)"
  grep -E 'ix86_|aarch64_' /tmp/t108-$b.txt | sed 's/^/      /'
done

echo
echo "=== 3. The six shared entry points are DEFINED once, in the selector"
sh_nm "nm -C $D/gcc/target-cumargs-select.o" > /tmp/t108-sel.txt || exit 9
grep -E ' T mt_(stack_boundary|preferred_stack_boundary|stack_slot_alignment|minimum_alignment|outgoing_reg_parm_stack_space|function_arg_regno_p)' \
  /tmp/t108-sel.txt | sed 's/^/    /'
echo "    COUNT = $(grep -cE ' T mt_(stack_boundary|preferred_stack_boundary|stack_slot_alignment|minimum_alignment|outgoing_reg_parm_stack_space|function_arg_regno_p)' /tmp/t108-sel.txt)  (expect 6)"

echo
echo "=== 4. function.o now CALLS them (undefined refs to the new names)"
grep -cE 'mt_(stack_boundary|preferred_stack_boundary|stack_slot_alignment|minimum_alignment|outgoing_reg_parm_stack_space|function_arg_regno_p)' \
  /tmp/t108-fn-u.txt | sed 's/^/    distinct mt_ frame refs in function.o: /'
grep -E 'mt_(stack_boundary|preferred_stack_boundary|stack_slot_alignment|minimum_alignment|outgoing_reg_parm_stack_space|function_arg_regno_p)' \
  /tmp/t108-fn-u.txt | sed 's/^/      /'
