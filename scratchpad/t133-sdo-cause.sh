#!/bin/sh
# #133 -- WHAT get_stack_dynamic_offset ACTUALLY RETURNS, read in the running
# cc1, for both bases.
#
# This arm exists because the codegen arm cannot run: the aarch64 arm of
# STACK_DYNAMIC_OFFSET needs `flag_stack_clash_protection && cfun->calls_alloca'
# and THAT COMBINATION WALLS in insn-emit on aarch64 (t133-alloca-wall.sh:
# `unspec_volatile [(const_int 0)] UNSPECV_GET_FPCR' unrecognised at pass
# vregs).  The wall is at `extract_insn' -- AFTER `instantiate_virtual_regs'
# has already called `get_stack_dynamic_offset' -- so the value can still be
# read even though no assembly is ever produced.
#
# ONE BREAKPOINT PER RUN, matched against gdb's OWN `^Breakpoint N, <fn>' stop
# line: an earlier arm on this project confirmed a breakpoint it never hit by
# matching `info breakpoints' instead.
#
# `--args' and NOT `gdb run <args>', which silently drops -ftarget-config.
# function.cc must have been rebuilt at -g3 (t133-dbg-sdo.sh); at -g0 every
# read is "No symbol table is loaded", once scored as a pass on this project.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b133}
TAG=${1:-run}
CC1=$B/gcc/cc1
TC=$B/gcc/../lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
TCX=$B/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
[ -x "$CC1" ] || { echo "FATAL no cc1"; exit 9; }
[ -f "$TC" ]  || { echo "FATAL no aarch64 specs-config"; exit 9; }
[ -f "$TCX" ] || { echo "FATAL no x86_64 specs-config"; exit 9; }
cp "$S/fn-clash.c" "$B/fn-clash.c" || exit 9

cat > "$B/gdbsdo.cmd" <<'EOF'
set confirm off
set pagination off
break get_stack_dynamic_offset
run
echo \nMT133 --- gdb stopped here:\n
frame
bt 3
echo \nMT133 the three gates of aarch64.h:1688:\n
p flag_stack_clash_protection
p cfun->calls_alloca
p crtl->outgoing_args_size
echo \nMT133 THE RETURN VALUE:\n
finish
quit
EOF

for arm in aarch64 x86_64; do
  case $arm in
    aarch64) cfg=$TC;  extra="-mlittle-endian -mabi=lp64" ;;
    x86_64)  cfg=$TCX; extra="" ;;
  esac
  echo "=========== ARM: $arm  ($TAG)"
  sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdbsdo.cmd --args $CC1 -quiet \
    -nostdinc $B/fn-clash.c $extra -O2 -fstack-clash-protection \
    -ftarget-config=$cfg -o $B/gdbsdo-$arm.s" \
    > "$B/gdbsdo-$TAG-$arm.out" 2> "$B/gdbsdo-$TAG-$arm.err"
  echo "gdb rc=$?"
  if grep -qE '^Breakpoint [0-9]+, get_stack_dynamic_offset' "$B/gdbsdo-$TAG-$arm.out"; then
    echo "  breakpoint CONFIRMED by gdb's own stop line: get_stack_dynamic_offset"
  else
    echo "  FATAL: gdb never reported a stop in get_stack_dynamic_offset;"
    echo "         every reading below belongs to some other function or to none."
  fi
  sed -n '/MT133/,$p' "$B/gdbsdo-$TAG-$arm.out"
  echo "-- stderr tail:"; tail -2 "$B/gdbsdo-$TAG-$arm.err"
done
