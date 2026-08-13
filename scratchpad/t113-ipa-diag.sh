#!/bin/sh
# TASK #112 -- what exactly faults in estimate_move_cost when aarch64 is the
# selected target, on `int f (int a) { return a + 1; }'.
#
# HYPOTHESIS: tree-inline.cc is shared code compiled against the PRIMARY base
# i386, so `MOVE_RATIO (speed_p)' there is i386.h:1968
#     ((speed) ? ix86_cost->move_ratio : 3)
# and ipa-prop.cc:395 passes speed_p = true.  `ix86_cost' is i386.cc:130
#     const struct processor_costs *ix86_cost = NULL;
# written only by ix86_option_override, which does not run when aarch64 is the
# selected target.  So the load is a NULL dereference.
#
# This is NOT arm D's shape: there is no #ifdef and nothing is absent.  It is
# a shared TU reaching into the PRIMARY BACK END'S MUTABLE STATE through a
# macro.  Arms B and C cannot see it either -- `ix86_cost' is a real defined
# symbol, so the link is clean.
#
# The script must be able to FAIL: it asserts the faulting instruction really
# is a load through ix86_cost, and that ix86_cost really is 0 at the time.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b113}
IN=${IN:-/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad/min.c}
O=${O:-/tmp/t113-ipa}
mkdir -p "$O"
[ -s "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }

# The tree is built with -g0, so there is NO DWARF: `p ix86_cost' fails with
# "no symbol in current context" even though the symbol exists.  Read it
# through the MINIMAL symbol table instead (`&ix86_cost' resolves, the type
# does not), and disassemble around the fault so the load is visible rather
# than inferred.  An earlier version of this script used `p ix86_cost', got
# nothing, and would have reported "not confirmed" for a missing type rather
# than for a wrong hypothesis.
cat > "$O/cmds.gdb" <<EOF
set pagination off
set confirm off
run -quiet -nostdinc -O2 -ftarget-config=specs-aarch64-unknown-linux-gnu-config $IN -o $O/out.s
echo \n===== SIGNAL FRAME =====\n
bt 6
echo \n===== ix86_cost: address, then the 8 bytes it holds =====\n
info address ix86_cost
x/1gx &ix86_cost
echo \n===== faulting instruction and its neighbourhood =====\n
x/i \$pc
x/6i \$pc-16
echo \n===== the address the fault touched =====\n
p/x \$_siginfo._sifields._sigfault.si_addr
echo \n===== for contrast, a pointer the SELECTED base owns =====\n
info address targetm_cdata
EOF

nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && gdb -batch -x $O/cmds.gdb ./cc1" > "$O/gdb.log" 2> "$O/gdb.err"
echo "gdb rc=$?  (stderr $(wc -l < "$O/gdb.err") lines)"
cat "$O/gdb.log"
echo
echo "===== VERDICT ====="
# ix86_cost holding 0, AND the fault address being a small offset from 0
# (move_ratio's offset within processor_costs), is the pair that makes the
# claim.  Either alone is weaker: a zero word proves nothing about what
# faulted, and a low si_addr proves nothing about WHICH pointer was null.
zero=no
grep -E '^0x[0-9a-f]+ <ix86_cost>:[[:space:]]+0x0000000000000000' "$O/gdb.log" \
  > /dev/null && zero=yes
low=no
sig=$(grep -A1 'the address the fault touched' "$O/gdb.log" | grep -oE '0x[0-9a-f]+$' | tail -1)
case "$sig" in
  0x0|0x[0-9a-f]|0x[0-9a-f][0-9a-f]) low=yes ;;
esac
echo "ix86_cost holds zero:            $zero"
echo "fault address (si_addr):         ${sig:-<not read>}   low-offset-from-null: $low"
if [ "$zero" = yes ] && [ "$low" = yes ]; then
  echo "CONFIRMED: the fault is a load through a NULL ix86_cost, at a small"
  echo "member offset -- i.e. MOVE_RATIO(true) == ix86_cost->move_ratio."
else
  echo "NOT CONFIRMED -- read the log above, do not assume."
fi
grep -q 'estimate_move_cost' "$O/gdb.log" \
  || echo "WARNING: estimate_move_cost not in the backtrace -- wrong fault?"
