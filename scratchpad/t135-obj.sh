#!/bin/sh
# #135 -- OBJECT-LEVEL, BOTH-SIDED EVIDENCE for the REG_PARM_STACK_SPACE and
# PUSH_ROUNDING conversions.
#
# Instrument notes, each of which has produced a false reading on this branch:
#   * `index ($0, f)' and never `$0 ~ f': the `()' in a demangled C++ name is
#     an EMPTY REGEX GROUP and matches nothing, which reads as "no per-base
#     copy exists" -- the opposite of the truth.
#   * A NON-VACUITY FLOOR on `nm': a tool that is missing, or an object that
#     is absent, otherwise scores 0 undefined symbols, i.e. "clean".
#   * The zeroes here are only findings because OTHER objects in the same run
#     still score 1 with the same instrument.
set -u
B=${B:-/tmp/b135}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
G=$B/gcc

nix-shell -I "nixpkgs=$NP" -p binutils --substituters 'https://cache.nixos.org/' --run '
set -u
G='"$G"'
command -v nm >/dev/null || { echo "FATAL: no nm"; exit 9; }
command -v objdump >/dev/null || { echo "FATAL: no objdump"; exit 9; }

# --- non-vacuity floor -----------------------------------------------------
tot=$(nm -uC $G/*.o 2>/dev/null | wc -l)
echo "non-vacuity: $tot undefined lines across \$G/*.o"
[ "$tot" -gt 50000 ] || { echo "FATAL: nm read almost nothing ($tot); no verdict below is trustworthy"; exit 9; }

count () {  # count <object> <demangled symbol substring>
  o=$1; f=$2
  [ -f "$o" ] || { echo "FATAL: no such object $o"; exit 9; }
  n=$(nm -uC "$o" | awk -v f="$f" '"'"'index ($0, f) { c++ } END { print c+0 }'"'"')
  printf "  %-28s %-46s %s\n" "$(basename $o)" "$f" "$n"
}

echo "--- ix86_reg_parm_stack_space: was 1 in calls.o and expr.o before #135"
count $G/calls.o    "ix86_reg_parm_stack_space"
count $G/expr.o     "ix86_reg_parm_stack_space"
count $G/function.o "ix86_reg_parm_stack_space"
echo "--- and the mt_ selectors that replaced them (must be NON-zero)"
count $G/calls.o "mt_has_reg_parm_stack_space"
count $G/calls.o "mt_reg_parm_stack_space"
count $G/expr.o  "mt_has_reg_parm_stack_space"
count $G/expr.o  "mt_reg_parm_stack_space"

echo "--- ix86_push_rounding: was 1 in several objects before #135"
for o in calls.o expr.o recog.o reload1.o lra-eliminations.o rtlanal.o \
         function.o cse.o targhooks.o combine-stack-adj.o; do
  count $G/$o "ix86_push_rounding"
done
echo "--- and mt_has_push_rounding / mt_push_rounding (must be NON-zero)"
for o in calls.o expr.o recog.o reload1.o lra-eliminations.o rtlanal.o \
         function.o cse.o targhooks.o combine-stack-adj.o; do
  count $G/$o "mt_has_push_rounding"
done

echo "--- THE THUNKS MUST DIFFER BETWEEN THE TWO BASES."
for b in i386 aarch64; do
  o=$G/target-cumargs-$b.o
  [ -f "$o" ] || { echo "FATAL: no $o"; exit 9; }
  echo "  == $b =="
  for f in mt_base_has_reg_parm_stack_space mt_base_reg_parm_stack_space \
           mt_base_has_push_rounding mt_base_push_rounding; do
    objdump -dr --disassemble="$f" "$o" 2>/dev/null \
      | awk -v f="$f" '"'"'index ($0, "<") && index ($0, f) { p=1 } p && NF'"'"' \
      | sed -n "3,12p" | sed "s/^/    $f: /"
  done
done
'
