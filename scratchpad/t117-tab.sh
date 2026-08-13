#!/bin/sh
# TASK #117 -- THE TAB ARM: read the RUNNING cc1, both sides.
#
# Header and object arms can only say which definitions exist.  This asks
# which one the process ENTERS, under each target config, by breaking on all
# three candidate addresses and reporting which breakpoint is hit first:
#
#     bare (the primary's, from the un-namespaced insn-opinit.o)
#     insn_i386::
#     insn_aarch64::
#
# BOTH SIDES IS THE POINT.  Showing that aarch64 now enters aarch64's handler
# proves nothing on its own -- "everyone now gets aarch64's answer" would look
# identical.  The i386 arm is what distinguishes a selector from a new
# hard-wiring, and the two arms must land on DIFFERENT symbols.
#
# Subject: init_all_optabs, because it runs unconditionally and early, so
# "never reached" is unambiguous.  Measured before this task's change, with
# aarch64 selected: the BARE one was entered and insn_aarch64's never was.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRCD=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a75a2f51f92af9802
D=${D:-/tmp/b117}
IN=${IN:-$SRCD/scratchpad/big.c}
O=${O:-/tmp/t117-tab}
mkdir -p "$O"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }
[ -s "$IN" ] || { echo "FATAL: no input"; exit 9; }

sym () {
  nix-shell -I "nixpkgs=$NP" -p binutils --run \
    "nm -C $D/gcc/cc1 | grep -x '[0-9a-f]* T $1' | awk '{print \$1}'"
}
A_BARE=$(sym 'init_all_optabs(target_optabs\*)')
A_I386=$(sym 'insn_i386::init_all_optabs(target_optabs\*)')
A_A64=$(sym  'insn_aarch64::init_all_optabs(target_optabs\*)')
for v in A_BARE A_I386 A_A64; do
  eval "x=\$$v"
  [ -n "$x" ] || { echo "FATAL: $v not found in cc1; refusing to score"; exit 9; }
done
echo "bare=0x$A_BARE  i386=0x$A_I386  aarch64=0x$A_A64"
# All three must be DISTINCT, or "which one was entered" is unanswerable and
# every arm below would be meaningless while looking fine.
[ "$A_BARE" != "$A_I386" ] && [ "$A_BARE" != "$A_A64" ] && [ "$A_I386" != "$A_A64" ] \
  || { echo "FATAL: two of the three addresses coincide; the arm cannot discriminate"; exit 9; }

rc=0
run_arm () {
  tgt=$1; want=$2; wantname=$3
  cat > "$O/c.gdb" <<EOF
set pagination off
set confirm off
break *0x$A_BARE
break *0x$A_I386
break *0x$A_A64
run -quiet -nostdinc -O2 -ftarget-config=specs-$tgt-config $IN -o $O/out-$tgt.s
frame 0
EOF
  nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && gdb -batch -x $O/c.gdb ./cc1" > "$O/$tgt.log" 2>&1
  # Which breakpoint number stopped first?  1=bare 2=i386 3=aarch64.
  got=$(grep -m1 '^Breakpoint [123],' "$O/$tgt.log" | sed 's/^Breakpoint \([123]\),.*/\1/')
  if [ -z "$got" ]; then
    echo "FAIL $tgt: no breakpoint was hit at all -- init_all_optabs never ran,"
    echo "     which is NOT evidence of correct selection"
    rc=1
    return
  fi
  case $got in
    1) name="bare (the primary's)";;
    2) name="insn_i386";;
    3) name="insn_aarch64";;
  esac
  if [ "$got" = "$want" ]; then
    echo "PASS $tgt: entered $name"
  else
    echo "FAIL $tgt: entered $name, wanted $wantname"
    rc=1
  fi
}

run_arm x86_64-pc-linux-gnu      2 insn_i386
run_arm aarch64-unknown-linux-gnu 3 insn_aarch64

echo
echo "t117-tab rc=$rc  (the two arms must have landed on DIFFERENT symbols)"
exit $rc
