#!/bin/sh
# #126 -- VERIFY the inherited diagnosis of the ninth wall rather than inherit it.
#
# The brief says `DEBUGGER_REGNO' carries TWO leaks.  Each arm below reads the
# RUNNING cc1, ONE BREAKPOINT PER RUN, and prints the breakpoint gdb itself
# reports so the reading can be matched against the function under test.
# PRINCIPLES section 4 rule 5: an arm that set three breakpoints in one run
# read the same function three times under three names.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b126}
IN=$B/big.c
CFG=$B/lib/gcc/17.0.0
A64="-mlittle-endian -mabi=lp64 -ftarget-config=$CFG/aarch64-unknown-linux-gnu/specs-config"
X64="-ftarget-config=$CFG/x86_64-pc-linux-gnu/specs-config"

cp "$S/big.c" "$B/big.c" || exit 9

run_gdb () { # $1 = cmds file, $2 = out file, $3 = target flags
  sh "$S/eb-shell-gdb.sh" \
    "cd $B/gcc && ulimit -v 4000000 && gdb -q -batch -nx -x $1 --args ./cc1 -quiet -nostdinc $IN -o /dev/null $3" \
    > "$2" 2>&1
}

echo "=== ARM 1: the absurd column, by NAME, with the frame gdb reports ==="
cat > "$B/c1.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break update_row_reg_save if column > 1000
run
info breakpoints
printf "MT126 column=%u\n", column
bt 3
kill
quit
EOF
run_gdb "$B/c1.cmds" "$B/c1.out" "$A64"
if grep -q 'MT126 column=' "$B/c1.out"; then
  grep -e 'in update_row_reg_save' -e 'MT126' "$B/c1.out" | head -4
  # the breakpoint gdb REPORTS must be the function under test
  if grep -q 'Breakpoint 1, update_row_reg_save' "$B/c1.out"; then
    echo "ARM1 FRAME-MATCH ok: gdb reports update_row_reg_save"
  else
    echo "ARM1 FRAME-MATCH FAIL: gdb did not report update_row_reg_save"
  fi
else
  echo "ARM1 NOT REACHED -- no column over 1000.  tail:"; tail -6 "$B/c1.out"
fi

echo
echo "=== ARM 2: WHICH MAP.  The two i386 maps disagree at gcc regno 4 ==="
echo "    (svr4/32-bit map[4] = 6, debugger64_register_map[4] = 4).  A reading"
echo "    of 6 means shared code took the 32-BIT branch, i.e. TARGET_64BIT was"
echo "    false -- the option-state half of the leak."
cat > "$B/c2.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break update_row_reg_save if column > 1000
run
info breakpoints
printf "MT126 isa_flags=%lu\n", (unsigned long) global_options.x_ix86_isa_flags
printf "MT126 TARGET_64BIT=%d\n", (int) ((global_options.x_ix86_isa_flags & 2) != 0)
printf "MT126 svr4_map4=%u dbg64_map4=%u\n", svr4_debugger_register_map[4], debugger64_register_map[4]
kill
quit
EOF
run_gdb "$B/c2.cmds" "$B/c2.out" "$A64"
grep -e 'MT126' -e 'Breakpoint 1, update' "$B/c2.out" | head -6
grep -q 'MT126 TARGET_64BIT=' "$B/c2.out" || { echo "ARM2 VACUOUS: nothing read"; }

echo
echo "=== ARM 3: BOUND vs INDEX.  i386's maps are declared"
echo "    [FIRST_PSEUDO_REGISTER] in i386's OWN translation unit (92), and"
echo "    shared code indexes them at the UNION width."
grep -n 'MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER' "$B/gcc/multi-target-reg-widths.h" \
  | head -2 || echo "ARM3 FAIL: no generated width header"

echo
echo "=== ARM 4: x86_64 POSITIVE CONTROL -- same instrument, must find nothing,"
echo "    in a run that really compiled ==="
cat > "$B/c4.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break update_row_reg_save if column > 1000
run
printf "MT126 x86 column=%u\n", column
kill
quit
EOF
run_gdb "$B/c4.cmds" "$B/c4.out" "$X64"
if grep -q 'MT126 x86 column=' "$B/c4.out"; then
  echo "ARM4 UNEXPECTED: x86_64 also has an absurd column"; grep MT126 "$B/c4.out"
else
  echo "ARM4 ok: no absurd column on x86_64"
fi
if grep -q 'exited normally' "$B/c4.out"; then
  echo "ARM4 NON-VACUITY ok: the x86_64 run reached exit, so \"no hit\" is not \"never got there\""
else
  echo "ARM4 NON-VACUITY FAIL: run did not complete; tail:"; tail -5 "$B/c4.out"
fi
