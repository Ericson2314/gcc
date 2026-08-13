#!/bin/sh
# #125 -- DIAGNOSE the explow.cc:102 wall.  #124 located it and explicitly
# declined to name a cause; `Pmode' was a named SUSPECT, not a finding.
#
# cc1 here is built with `-g0', so nothing reads a local by name.  Values come
# from the SysV argument registers at function entry and from the rtx header
# layout (`code:16, mode:8'), i.e. byte 2 of the rtx.  That is the same
# constraint #124's ARM 2 worked under ($rax after `finish').
#
# ONE BREAKPOINT PER RUN, and the breakpoint gdb REPORTS is matched against the
# function under test before any value is scored.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b125}
CC1=$B/gcc/cc1
IN=$B/big.c
[ -x "$CC1" ] || { echo "FATAL no cc1 at $CC1"; exit 9; }
[ -s "$IN" ]  || { echo "FATAL no big.c at $IN"; exit 9; }

# What SImode/DImode actually are in THIS build, read out of the generated
# header rather than remembered.  The mode union means one numbering; if that
# were not so this whole reading would be meaningless.
echo "=== mode numbering in this build, read out of the generated header ==="
MODEH=$(ls "$B/gcc/insn-modes.h" "$B/gcc/mt-"*/insn-modes.h 2>/dev/null | head -1)
[ -n "$MODEH" ] || { echo "FATAL: no generated insn-modes.h found under $B/gcc"; exit 9; }
echo "  from $MODEH"
grep -w -e 'E_SImode' -e 'E_DImode' "$MODEH" | head -4
echo

# The driver's own cc1 line (from `-v') is the authority for these; a guessed
# invocation is how you end up measuring a cc1 that refused to start.
CFG=/tmp/b125/lib/gcc/17.0.0
A64_ARGS="-mlittle-endian -mabi=lp64 -ftarget-config=$CFG/aarch64-unknown-linux-gnu/specs-config"
X86_ARGS="-ftarget-config=$CFG/x86_64-pc-linux-gnu/specs-config"

gdb_one () {  # gdb_one <label> <cc1-target-args> <cmds-file>
  P="$B/cause-$1.txt"
  sh "$S/eb-shell-gdb.sh" \
     "cd $B/gcc && gdb -q -batch -nx -x $3 --args ./cc1 -quiet -nostdinc $IN -o /dev/null $2" \
     > "$P" 2>&1
  [ -s "$P" ] || { echo "FATAL non-vacuity: gdb produced no output for $1"; exit 9; }
  grep -q 'Breakpoint 2' "$P" && { echo "FATAL: >1 breakpoint in a one-breakpoint run"; exit 9; }
  grep -q 'Breakpoint 1,' "$P" || {
    echo "FATAL non-vacuity: gdb never stopped at the breakpoint for $1."
    echo "  'not hit' is indistinguishable from 'nothing is wrong'."
    tail -12 "$P"; exit 9; }
  cat "$P"
}

# ---------------------------------------------------------------- ARM A
# The failing call.  Break on plus_constant, read the MODE argument (edi) and
# the mode of the rtx X (rsi -> byte 2), at ENTRY, before anything runs.
# The breakpoint CONDITION selects the call that trips the assert, so the
# reading is of the FAILING call and not of the first of thousands -- and it
# stays a normal stop, so gdb still reports "Breakpoint 1," and the shared
# non-vacuity check above can see that it was reached at all.
cat > "$B/gdb-a.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break plus_constant if *(unsigned short *)$rsi != 0 && (unsigned) $edi != *(unsigned short *)$rsi
run
printf "MTCAUSE mode_arg=%u mode_of_x=%u\n", (unsigned) $edi, *(unsigned short *)$rsi
bt 5
kill
quit
EOF
echo "=== ARM A: the mismatching plus_constant call, aarch64 ==="
gdb_one a "$A64_ARGS" "$B/gdb-a.cmds"
echo

# ---------------------------------------------------------------- ARM B
# THE POSITIVE CONTROL for the other side.  Same breakpoint, condition
# REMOVED, in the x86_64 run.  Without this, ARM C's "no mismatch" reading is
# indistinguishable from "the breakpoint never worked in this run" -- the
# all-empty-probe failure PRINCIPLES section 7 records.
cat > "$B/gdb-b.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break plus_constant
run
printf "MTCAUSE control mode_arg=%u mode_of_x=%u\n", (unsigned) $edi, *(unsigned short *)$rsi
kill
quit
EOF
echo "=== ARM B: positive control -- the same breakpoint DOES fire in the x86_64 run ==="
gdb_one b "$X86_ARGS" "$B/gdb-b.cmds"
echo

# ---------------------------------------------------------------- ARM C
# The other side proper: the SAME mismatch condition, x86_64.  Expected to
# find nothing, which is only meaningful because ARM B showed the instrument
# is live in this run.  `gdb_one' would FATAL on a no-hit, so this one is run
# directly and scored the other way round.
cat > "$B/gdb-c.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break plus_constant if *(unsigned short *)$rsi != 0 && (unsigned) $edi != *(unsigned short *)$rsi
run
printf "MTCAUSE x86-ran-to-completion-with-no-mode-mismatch\n"
quit
EOF
echo "=== ARM C: the same mismatch condition on x86_64 -- must find none ==="
sh "$S/eb-shell-gdb.sh" \
  "cd $B/gcc && gdb -q -batch -nx -x $B/gdb-c.cmds --args ./cc1 -quiet -nostdinc $IN -o $B/cause-c.s $X86_ARGS" \
  > "$B/cause-c.txt" 2>&1
if grep -q 'Breakpoint 1,' "$B/cause-c.txt"; then
  echo "MISMATCH FOUND ON X86 TOO -- the reading above is NOT a divergence:"
  grep -A3 'Breakpoint 1,' "$B/cause-c.txt" | head -8
else
  grep 'MTCAUSE' "$B/cause-c.txt"
  # `no hit' must not be `no compile'.  Assert the run actually produced code.
  if [ -s "$B/cause-c.s" ]; then
    echo "  and it really compiled: $(wc -c < "$B/cause-c.s") bytes of x86_64 asm"
  else
    echo "FATAL: x86_64 run produced no asm, so `no mismatch' means `never got there'"
    exit 9
  fi
fi
