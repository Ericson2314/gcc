#!/bin/sh
# TASK #113 -- the `int x = 1;' fault, reported by the tool-paths agent as an
# ICE "in ix86_data_alignment".
#
# WHY IT IS WORTH CONFIRMING RATHER THAN BELIEVING.  The claim arrives as a
# NAME, and PRINCIPLES 7 says a symbol's name does not tell you which macro
# pulled it in -- `function.cc' references `ix86_local_alignment' from
# STACK_SLOT_ALIGNMENT, not from the LOCAL_ALIGNMENT the name suggests.  So
# the question here is not "is ix86_data_alignment on the stack" but "WHAT
# INSIDE IT FAULTED, and is that the same mechanism as MOVE_RATIO".
#
# The two candidate sub-shapes, which the coordinator is right that a filter
# must distinguish:
#   (a) the macro itself dereferences a back-end POINTER -- MOVE_RATIO's
#       `ix86_cost->move_ratio'.  Visible in the macro body.
#   (b) the macro CALLS a back-end FUNCTION which then reads uninitialised
#       state.  INVISIBLE in the macro body; only the run tells you.
# `DATA_ALIGNMENT' is spelled `ix86_data_alignment (TYPE, ALIGN)' in
# i386.h, so it is (b) if it faults at all.
#
# -g0 tree: read globals through the minimal symbol table, never `p sym'.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b113}
O=${O:-/tmp/t113-align}
mkdir -p "$O"
printf 'int x = 1;\n' > "$O/tiny.c"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 at $D/gcc/cc1"; exit 9; }
[ -s "$D/gcc/specs-aarch64-unknown-linux-gnu-config" ] \
  || { echo "FATAL: no aarch64 config -- run t113-ts.sh"; exit 9; }

cat > "$O/cmds.gdb" <<EOF
set pagination off
set confirm off
run -quiet -nostdinc -O2 -ftarget-config=specs-aarch64-unknown-linux-gnu-config $O/tiny.c -o $O/out.s
echo \n===== SIGNAL FRAME =====\n
bt 12
echo \n===== faulting instruction and its neighbourhood =====\n
x/i \$pc
x/8i \$pc-24
echo \n===== the address the fault touched =====\n
p/x \$_siginfo._sifields._sigfault.si_addr
echo \n===== back-end pointers ix86_option_override would have written =====\n
info address ix86_cost
x/1gx &ix86_cost
info address ix86_tune_cost
x/1gx &ix86_tune_cost
echo \n===== registers, so the base of the faulting load is readable =====\n
info registers rax rbx rcx rdx rsi rdi
EOF

nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && gdb -batch -x $O/cmds.gdb ./cc1" > "$O/gdb.log" 2> "$O/gdb.err"
echo "gdb rc=$?  (stderr $(wc -l < "$O/gdb.err") lines)"
cat "$O/gdb.log"

echo
echo "===== VERDICT ====="
# NON-VACUITY: a gdb run that never reached a SIGSEGV proves nothing, and an
# empty log looks exactly like "hypothesis not confirmed".  Refuse to score.
grep -q 'SIGSEGV\|Program received signal' "$O/gdb.log" \
  || { echo "FATAL: no signal in the log -- the instrument did not observe a fault"; exit 9; }
sig=$(grep -A1 'the address the fault touched' "$O/gdb.log" \
      | grep -oE '0x[0-9a-f]+$' | tail -1)
echo "si_addr:            ${sig:-<not read>}"
echo "ix86_cost:          $(grep -A1 'ix86_cost>:' "$O/gdb.log" | grep -oE '0x[0-9a-f]{16}' | head -1)"
echo -n "ix86_data_alignment on the stack: "
grep -q 'ix86_data_alignment' "$O/gdb.log" && echo YES || echo "NO -- the reported name is not what faulted"
