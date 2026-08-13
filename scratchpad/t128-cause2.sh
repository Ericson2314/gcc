#!/bin/sh
# #128 -- SECOND READING.  The constraint vocabulary is fixed (t128-cause.sh:
# `k' now answers aarch64's STACK_REG and not i386's NO_REGS) and the insn is
# STILL rejected, so something else in `constrain_operands' disagrees.
#
# Candidates, and this run distinguishes them rather than assuming:
#   (1) the ALTERNATIVES are all disabled -- `recog_data.enabled_alternatives'
#       comes from `get_attr_enabled', which lives in the un-namespaced
#       `insn-attrtab.o', i.e. the PRIMARY's attribute table;
#   (2) `reg_class_contents[STACK_REG]' does not contain register 31.
#
# ONE BREAKPOINT PER RUN, and gdb's own reported breakpoint is printed.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b128}
CC1=$B/gcc/cc1
TC=$B/gcc/../lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
TCX=$B/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
[ -x "$CC1" ] || { echo "FATAL no cc1"; exit 9; }
printf 'int g (int a) { return a + 1; }\n' > "$B/fn-add.c"

cat > "$B/gdb-c.cmd" <<EOF
set confirm off
set pagination off
break _fatal_insn_not_found
info breakpoints
run
echo \nMT128 --- gdb stopped here:\n
frame
echo \nMT128 n_alternatives:\n
p recog_data.n_alternatives
echo \nMT128 INSN_CODE of the insn under test:\n
p recog_data.n_operands
echo \nMT128 cached bool_attr_masks[157][BA_ENABLED,SIZE,SPEED]:\n
p /x this_target_recog->x_bool_attr_masks[157][0]
p /x this_target_recog->x_bool_attr_masks[157][1]
p /x this_target_recog->x_bool_attr_masks[157][2]
echo \nMT128 operand[0] regno / operand[1] regno:\n
p recog_data.operand[0]->u.fld[0].rt_uint
p recog_data.operand[1]->u.fld[0].rt_uint
echo \nMT128 reg_class_contents[5] (aarch64 GENERAL_REGS):\n
p /x this_target_hard_regs->x_reg_class_contents[5]
echo \nMT128 reg_class_contents[6] (aarch64 STACK_REG):\n
p /x this_target_hard_regs->x_reg_class_contents[6]
echo \nMT128 reg_class_size[5] reg_class_size[6]:\n
p this_target_hard_regs->x_reg_class_size[5]
p this_target_hard_regs->x_reg_class_size[6]
quit
EOF

cat > "$B/gdb-d.cmd" <<EOF
set confirm off
set pagination off
break _fatal_insn_not_found
info breakpoints
run
echo \nMT128 x86_64 run finished\n
quit
EOF

echo "=========== ARM C: aarch64, one breakpoint (_fatal_insn_not_found)"
sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdb-c.cmd --args $CC1 -quiet -nostdinc \
  $B/fn-add.c -mlittle-endian -mabi=lp64 -ftarget-config=$TC -o $B/gdb-c.s" \
  > "$B/gdb-c.out" 2> "$B/gdb-c.err"
echo "gdb rc=$?"
cat "$B/gdb-c.out"
echo "-- stderr tail:"; tail -3 "$B/gdb-c.err"

echo "=========== ARM D: x86_64 NON-VACUITY control"
sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdb-d.cmd --args $CC1 -quiet -nostdinc \
  $B/fn-add.c -ftarget-config=$TCX -o $B/gdb-d.s" \
  > "$B/gdb-d.out" 2> "$B/gdb-d.err"
if grep -q 'MT128 x86_64 run finished' "$B/gdb-d.out" \
   && grep -q 'exited normally' "$B/gdb-d.out"; then
  echo "  NON-VACUITY ok: gdb ran and the x86_64 compile reached exit"
else
  echo "  NON-VACUITY FAIL: ARM C's reading is not trustworthy"
fi
