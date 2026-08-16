#!/bin/sh
# agent-a97cff7619d3cabd9-gdb.sh -- WHICH regno arrives at recog.cc:1598.
#
# The static probe (`-vregno.sh') shows the two authorities disagree; this
# shows the number that actually crosses the call, because "the macro differs"
# and "a regno from the wrong side reached the assert" are two claims.
#
# ONE breakpoint per run, and gdb's own reported breakpoint is matched against
# the function under test (PRINCIPLES 4, rule 5: three breakpoints in one run
# were all read as the first one that fired).
#
# usage: agent-a97cff7619d3cabd9-gdb.sh <builddir>
set -u
D=${1:?build dir}
case "$D" in */b-a97cff7619d3cabd9*) ;; *) echo "FATAL: not this worktree's build dir"; exit 9 ;; esac
SRC=$(cat "$D/MY-SRC"); V=$(cat "$SRC/gcc/BASE-VER")
CFG="$D/lib/gcc/$V/x86_64-pc-linux-gnu/specs-config"
IN="$SRC/gcc/testsuite/gcc.c-torture/compile/pr118362.c"
O="$D/gdb-vregno"; rm -rf "$O"; mkdir -p "$O"
cat > "$O/cmds" <<'EOF'
set pagination off
set confirm off
break fancy_abort
run
echo \n== BACKTRACE ==\n
bt 12
echo \n== THE REGNO AT recog.cc general_operand ==\n
frame 2
info frame
p /d op->u.reg.regno
p /d op->u.reg.regno
EOF
( cd "$D/gcc" && gdb -batch -x "$O/cmds" --args ./cc1 -quiet -nostdinc -O2 \
    -ftarget-config="$CFG" "$IN" -o "$O/x.s" ) > "$O/gdb.out" 2> "$O/gdb.err"
echo "gdb rc=$?"
cat "$O/gdb.out"
