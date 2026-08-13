#!/bin/sh
# #128 -- THE DIAGNOSIS, read in the RUNNING cc1.  ONE BREAKPOINT PER RUN.
#
# Claim under test: `constrain_operands' is SHARED code, and the constraint
# vocabulary it uses -- lookup_constraint / reg_class_for_constraint, inline in
# tm-preds.h, backed by `lookup_constraint_1' and `reg_class_for_constraint_1'
# -- is the PRIMARY's (i386's) for every back end.  aarch64's
# `*adddi3_aarch64' spells "rk"; `k' is aarch64's STACK_REG and i386's
# ALL_MASK_REGS-or-NO_REGS, so aarch64's real SP is rejected.
#
# TRAPS OBEYED:
#  * `gdb run <args>' silently drops `-ftarget-config'; `--args' is used.
#  * ONE breakpoint per run, and gdb's OWN reported breakpoint line is printed
#    so it can be matched against the function under test.
#  * ARM B is the NON-VACUITY control: the x86_64 run must reach exit, so
#    "the breakpoint did not fire" cannot be confused with "gdb never started".
#  * the calls into the three vocabularies are made through explicit function
#    pointers on the MANGLED names, because insn-preds*.o carry no debug info
#    and an unqualified name would be ambiguous across three namespaces.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b128}
CC1=$B/gcc/cc1
TC=$B/gcc/../lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
TCX=$B/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config

[ -x "$CC1" ] || { echo "FATAL no cc1"; exit 9; }
[ -f "$TC" ] || { echo "FATAL no aarch64 specs-config at $TC"; exit 9; }
[ -f "$TCX" ] || { echo "FATAL no x86_64 specs-config at $TCX"; exit 9; }
printf 'int g (int a) { return a + 1; }\n' > "$B/fn-add.c"

LC='p ((int (*)(const char *)) _Z19lookup_constraint_1PKc) ("k")'
LA='p ((int (*)(const char *)) _ZN12insn_aarch6419lookup_constraint_1EPKc) ("k")'
LI='p ((int (*)(const char *)) _ZN9insn_i38619lookup_constraint_1EPKc) ("k")'

cat > "$B/gdb-a.cmd" <<EOF
set confirm off
set pagination off
break _fatal_insn_not_found
info breakpoints
run
echo \nMT128 --- gdb stopped here:\n
frame
echo \nMT128 n_operands:\n
p recog_data.n_operands
echo \nMT128 constraints:\n
p recog_data.constraints[0]
p recog_data.constraints[1]
p recog_data.constraints[2]
echo \nMT128 which_alternative:\n
p which_alternative
echo \nMT128 GLOBAL lookup_constraint_1("k") = \n
$LC
echo \nMT128 insn_aarch64 lookup_constraint_1("k") = \n
$LA
echo \nMT128 insn_i386 lookup_constraint_1("k") = \n
$LI
echo \nMT128 GLOBAL reg_class_for_constraint_1(GLOBAL k) = \n
p ((int (*)(int)) _Z26reg_class_for_constraint_114constraint_num) (((int (*)(const char *)) _Z19lookup_constraint_1PKc) ("k"))
echo \nMT128 insn_aarch64 reg_class_for_constraint_1(aarch64 k) = \n
p ((int (*)(int)) _ZN12insn_aarch6426reg_class_for_constraint_1ENS_14constraint_numE) (((int (*)(const char *)) _ZN12insn_aarch6419lookup_constraint_1EPKc) ("k"))
echo \nMT128 insn_i386 reg_class_for_constraint_1(i386 k) = \n
p ((int (*)(int)) _ZN9insn_i38626reg_class_for_constraint_1ENS_14constraint_numE) (((int (*)(const char *)) _ZN9insn_i38619lookup_constraint_1EPKc) ("k"))
echo \nMT128 SELECTED mt_lookup_constraint("k") = \n
p ((int (*)(const char *)) _Z20mt_lookup_constraintPKc) ("k")
echo \nMT128 SELECTED mt_reg_class_for_constraint(that) = \n
p ((int (*)(int)) _Z27mt_reg_class_for_constrainti) (((int (*)(const char *)) _Z20mt_lookup_constraintPKc) ("k"))
echo \nMT128 SELECTED mt_lookup_constraint("r") = \n
p ((int (*)(const char *)) _Z20mt_lookup_constraintPKc) ("r")
echo \nMT128 SELECTED mt_reg_class_for_constraint(r) = \n
p ((int (*)(int)) _Z27mt_reg_class_for_constrainti) (((int (*)(const char *)) _Z20mt_lookup_constraintPKc) ("r"))
echo \nMT128 targetm_preds->name = \n
p ((const char **) &targetm_preds)[0]
quit
EOF

cat > "$B/gdb-b.cmd" <<EOF
set confirm off
set pagination off
break _fatal_insn_not_found
info breakpoints
run
echo \nMT128 x86_64 run finished\n
quit
EOF

echo "=========== ARM A: aarch64, one breakpoint (_fatal_insn_not_found)"
sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdb-a.cmd --args $CC1 -quiet -nostdinc \
  $B/fn-add.c -mlittle-endian -mabi=lp64 -ftarget-config=$TC -o $B/gdb-a.s" \
  > "$B/gdb-a.out" 2> "$B/gdb-a.err"
echo "gdb rc=$?"
grep -E 'MT128|Breakpoint 1|\\$[0-9]+ =|^#0' "$B/gdb-a.out" | sed 's/^/  /'
echo "-- stderr tail:"; tail -3 "$B/gdb-a.err" | sed 's/^/  /'

echo "=========== ARM B: x86_64 NON-VACUITY control (same breakpoint, must not fire, must reach exit)"
sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdb-b.cmd --args $CC1 -quiet -nostdinc \
  $B/fn-add.c -ftarget-config=$TCX -o $B/gdb-b.s" \
  > "$B/gdb-b.out" 2> "$B/gdb-b.err"
echo "gdb rc=$?"
grep -E 'MT128|Breakpoint 1|exited' "$B/gdb-b.out" | sed 's/^/  /'
if grep -q 'MT128 x86_64 run finished' "$B/gdb-b.out" \
   && grep -q 'exited normally' "$B/gdb-b.out"; then
  echo "  NON-VACUITY ok: gdb ran and the x86_64 compile reached exit without the breakpoint"
else
  echo "  NON-VACUITY FAIL: gdb may never have started -- ARM A's reading is not trustworthy"
fi
