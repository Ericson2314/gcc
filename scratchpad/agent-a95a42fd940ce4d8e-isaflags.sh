#!/bin/sh
# agent-a95a42fd940ce4d8e-isaflags.sh -- WHY does shared code read TImode for
# six back ends and DImode for four, when neither is those back ends' answer?
#
# i386.h:2011 is
#   ((LEVEL) == SAVE_NONLOCAL ? (TARGET_64BIT ? TImode : DImode) : Pmode)
# and `TARGET_64BIT' is `((ix86_isa_flags & OPTION_MASK_ISA_64BIT) != 0)', i.e.
# `global_options.x_ix86_isa_flags' -- OPTION STATE, which PRINCIPLES records
# as the one class `nm -uC' is structurally blind to: no object anywhere
# carries an undefined reference naming it, because it is a struct member
# shared code legitimately links against.
#
# So the prediction to test is that the split is not about the back ends at all
# -- it is x86 option state read at a moment that differs per selection.  This
# reads the variable in the running cc1 rather than reasoning about its Init.
#
# ONE BREAKPOINT PER RUN, and gdb's OWN reported breakpoint is matched against
# the function under test: PRINCIPLES records an arm that set three
# breakpoints, assumed they fired in the order written, and read one function's
# return value three times under three different names.
set -u
D=${D:-/tmp/b-a95a42fd940ce4d8e}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/isa}
SRC=$(cat "$D/MY-SRC"); V=$(cat "$SRC/gcc/BASE-VER")
mkdir -p "$O"
command -v gdb > /dev/null || { echo "FATAL: no gdb"; exit 9; }
IN=$SRC/gcc/testsuite/gcc.c-torture/compile/pr21728.c
printf '%-30s %-22s %s\n' TARGET ix86_isa_flags 'TARGET_64BIT -> savearea mode'
for t in arm-unknown-eabi alpha-unknown-linux-gnu avr-unknown-elf \
         x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  c="$D/lib/gcc/$V/$t/specs-config"
  [ -s "$c" ] || { printf '%-30s %s\n' "$t" NO-SPECS; continue; }
  w="$O/$t"; rm -rf "$w"; mkdir -p "$w"; cp "$IN" "$w/in.c"
  cat > "$w/cmds" <<'EOF'
set confirm off
set pagination off
break expand_builtin_nonlocal_goto
run
info breakpoints
print/x global_options.x_ix86_isa_flags
EOF
  ( cd "$w" && timeout -s INT 120s gdb -batch -x cmds --args \
      "$D/gcc/cc1" -quiet -nostdinc -O1 -ftarget-config="$c" in.c -o out.s ) \
      > "$w/gdb.out" 2> "$w/gdb.err"
  # Match gdb's own reported breakpoint against the function under test.
  if ! grep -q 'expand_builtin_nonlocal_goto' "$w/gdb.out"; then
    printf '%-30s %s\n' "$t" "BP-NEVER-HIT (not a reading)"; continue
  fi
  f=$(grep -m1 '^\$1 = ' "$w/gdb.out" | sed 's/^\$1 = //')
  [ -n "$f" ] || f=NO-VALUE
  printf '%-30s %-22s %s\n' "$t" "$f" ""
done
echo
echo "OPTION_MASK_ISA_64BIT is the bit TARGET_64BIT tests; a set bit selects TImode."
echo "raw gdb output under $O/<target>/gdb.out"
