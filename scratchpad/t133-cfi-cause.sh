#!/bin/sh
# #131 -- WHAT CARRIES THE WRONG CFI, measured in the running cc1.
#
# The emitted aarch64 prologue is right and its unwind data is not: the entry
# `.cfi_def_cfa_offset 16' should be absent (CFA = sp+0 at entry on aarch64).
# Two named candidates were handed over UNDIAGNOSED -- INCOMING_FRAME_SP_OFFSET
# and DEFAULT_INCOMING_FRAME_SP_OFFSET, both i386.h's, neither defined by
# aarch64 -- and "16 is not UNITS_PER_WORD (8) on its face" was the reason the
# previous agent declined to name one.  This arm reads BOTH, in cc1, for BOTH
# bases.
#
# ONE BREAKPOINT PER RUN, matched against gdb's own `^Breakpoint N, <fn>' STOP
# line and against the backtrace -- an arm that matched `info breakpoints'
# instead once confirmed a breakpoint it never hit.
#
# `--args', NOT `gdb run <args>': the latter silently drops -ftarget-config and
# the whole reading would be of a compiler that selected no target.
#
# dwarf2cfi.cc must have been rebuilt with -g (t133-dbg.sh) or every read is
# "No symbol table is loaded", which #126 recorded being scored as a pass.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
CC1=$B/gcc/cc1
TC=$B/gcc/../lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
TCX=$B/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
[ -x "$CC1" ] || { echo "FATAL no cc1"; exit 9; }
[ -f "$TC" ]  || { echo "FATAL no aarch64 specs-config"; exit 9; }
[ -f "$TCX" ] || { echo "FATAL no x86_64 specs-config"; exit 9; }
printf 'int g (int a) { return a + 1; }\n' > "$B/fn-add.c"

mkcmd () {
cat <<'EOF'
set confirm off
set pagination off
break scan_trace
info breakpoints
run
echo \nMT131 --- gdb stopped here:\n
frame
bt 3
echo \nMT131 is this the ENTRY trace (the arg that gates the offset note):\n
p entry
echo \nMT131 INCOMING_FRAME_SP_OFFSET, i386.h:2177, as cc1 evaluates it:\n
p (cfun->machine->func_type == TYPE_EXCEPTION) ? 2*UNITS_PER_WORD : UNITS_PER_WORD
echo \nMT131 the two halves of that expression:\n
p cfun->machine->func_type
p UNITS_PER_WORD
echo \nMT131 DEFAULT_INCOMING_FRAME_SP_OFFSET, i386.h:2183 = UNITS_PER_WORD:\n
p UNITS_PER_WORD
echo \nMT131 the CFA offset this trace starts from:\n
p cur_row->cfa.offset
quit
EOF
}

for arm in aarch64 x86_64; do
  case $arm in
    aarch64) cfg=$TC;  extra="-mlittle-endian -mabi=lp64" ;;
    x86_64)  cfg=$TCX; extra="" ;;
  esac
  mkcmd > "$B/gdbcfi-$arm.cmd"
  echo "=========== ARM: $arm"
  sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdbcfi-$arm.cmd --args $CC1 -quiet \
    -nostdinc $B/fn-add.c $extra -ftarget-config=$cfg -o $B/gdbcfi-$arm.s" \
    > "$B/gdbcfi-$arm.out" 2> "$B/gdbcfi-$arm.err"
  echo "gdb rc=$?"
  if grep -qE '^Breakpoint [0-9]+, scan_trace' "$B/gdbcfi-$arm.out"; then
    echo "  breakpoint CONFIRMED by gdb's own stop line: scan_trace"
  else
    echo "  FATAL: gdb never reported a stop in scan_trace; every reading below"
    echo "         belongs to some other function or to no function at all."
  fi
  sed -n '/MT131/,$p' "$B/gdbcfi-$arm.out"
  echo "-- stderr tail:"; tail -2 "$B/gdbcfi-$arm.err"
done
