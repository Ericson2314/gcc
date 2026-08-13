#!/bin/sh
# TASK #113 -- where aarch64 stops NOW, under gdb, on scratchpad/big.c.
#
# The point is to name the NEXT wall rather than report "still ICEs", and to
# say which arm it belongs to.  #112 predicted the next one would be another
# arm E member rather than an arm D one; this is the check of that prediction,
# and a prediction that is not checked is not a finding.
#
# -g0 tree: read globals through the minimal symbol table (`x/1gx &sym'),
# never `p sym' -- #112's trap 2, where an untyped symbol made a CORRECT
# hypothesis read as "not confirmed".
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b113}
IN=${IN:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098/scratchpad/big.c}
O=${O:-/tmp/t113-wall}
mkdir -p "$O"
[ -s "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }

cat > "$O/cmds.gdb" <<EOF
set pagination off
set confirm off
run -quiet -nostdinc -O2 -ftarget-config=specs-aarch64-unknown-linux-gnu-config $IN -o $O/out.s
echo \n===== SIGNAL FRAME =====\n
bt 15
echo \n===== faulting instruction =====\n
x/i \$pc
x/6i \$pc-20
echo \n===== si_addr =====\n
p/x \$_siginfo._sifields._sigfault.si_addr
echo \n===== the primary's uninitialised cost pointers =====\n
x/1gx &ix86_cost
x/1gx &ix86_tune_cost
EOF

nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && gdb -batch -x $O/cmds.gdb ./cc1" > "$O/gdb.log" 2> "$O/gdb.err"
echo "gdb rc=$?"
cat "$O/gdb.log"
grep -q 'Program received signal' "$O/gdb.log" \
  || { echo "FATAL: no fault observed -- instrument said nothing, which is NOT 'it works'"; exit 9; }
