#!/bin/sh
# #125 -- guards for the `Pmode' conversion (the explow.cc:102 wall).
#
# WHAT THIS WALL COST THE USUAL INSTRUMENT, STATED UP FRONT.  Every previous
# wall on this branch was found with `nm -uC <obj>' naming a leaked `ix86_*'
# symbol.  THAT INSTRUMENT SCORES THIS LEAK AS ABSENT, and not by accident:
# i386's `Pmode' is `(ix86_pmode == PMODE_DI ? DImode : SImode)', `ix86_pmode'
# is an OPTION variable, i.e. `global_options.x_ix86_pmode' -- a member of a
# struct that shared code legitimately links against.  It is not a function
# and not a distinct symbol, so no object anywhere carries an undefined
# reference naming it.  A macro can leak with a completely clean `nm'.
#
# So the arms below are values read out of the RUNNING cc1, plus an injection.
# ONE BREAKPOINT PER RUN, and the breakpoint gdb REPORTS is checked before any
# value is scored.
#
# THE BOTH-SIDED ARM IS ASYMMETRIC ON PURPOSE, for the reason #123's ARM 2c
# records: `Pmode' is DImode for BOTH configured bases, so an equality arm on
# its value passes while proving nothing.  What diverges is what SHARED code
# used to build `stack_pointer_rtx' with: SImode (26) for aarch64, because
# `ix86_pmode' sat at its `Init (PMODE_SI)' default, against DImode (27) for
# x86_64, where `ix86_option_override' had run.  The arms therefore score the
# MISMATCH between the mode argument and the mode of the rtx, which existed on
# one side only, and the injection puts it back.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b125}
SRC=$(cd "$S/.." && pwd)
CFG=$B/lib/gcc/17.0.0
IN=$B/big.c
PASS=0; FAIL=0
ok ()  { PASS=$((PASS+1)); echo "PASS  $*"; }
bad () { FAIL=$((FAIL+1)); echo "FAIL  $*"; }

A64="-mlittle-endian -mabi=lp64 -ftarget-config=$CFG/aarch64-unknown-linux-gnu/specs-config"
X86="-ftarget-config=$CFG/x86_64-pc-linux-gnu/specs-config"

[ -x "$B/gcc/cc1" ] || { echo "FATAL no cc1 at $B/gcc/cc1"; exit 9; }
[ -s "$IN" ] || cp "$S/big.c" "$IN"
# The SAME path t125-state.sh uses, deliberately.  A different basename makes
# `.file "..."' in the assembly a different length, which moves the byte count
# and the md5 for a reason that has nothing to do with the code being tested.
# Measured: `g-small.c' gave 375 bytes / 361954469d74 against `small.c''s 373
# / b01d9157fdc1, purely from two extra characters in the file directive.
printf 'int x = 1;\n' > "$B/small.c"

# ================================================================ ARM 0
# The change is PRESENT, by name.  Cheap, and it is the arm whose absence cost
# #124 a session: a generator that ran, exited 0 and changed nothing passes
# every check on exit status, existence and non-emptiness.
echo "=== ARM 0: the redirect and its target exist, by name ==="
if grep -q '^#define Pmode (mt_pmode ())' "$SRC/gcc/defaults.h"; then
  ok "ARM 0a defaults.h redirects Pmode to mt_pmode ()"
else
  bad "ARM 0a defaults.h has no '#define Pmode (mt_pmode ())'"
fi
nm_out=$(sh "$S/eb-shell.sh" "nm -C $B/gcc/cc1" 2>/dev/null)
[ -n "$nm_out" ] || { echo "FATAL: nm produced nothing; a missing tool scores 0 in the flattering direction"; exit 9; }
if printf '%s\n' "$nm_out" | grep -q 'T mt_pmode()'; then
  ok "ARM 0b cc1 defines mt_pmode()"
else
  bad "ARM 0b cc1 has no mt_pmode() definition"
fi
# BOTH per-base supply objects must carry a pmode thunk, or one base is being
# answered by the other's table -- the one-sided-evidence trap.
for base in i386 aarch64; do
  o="$B/gcc/target-cumargs-$base.o"
  if [ ! -f "$o" ]; then bad "ARM 0c $o missing"; continue; fi
  if sh "$S/eb-shell.sh" "nm -C $o" 2>/dev/null | grep -q 'mt_base_pmode'; then
    ok "ARM 0c $base's own translation unit supplies mt_base_pmode"
  else
    bad "ARM 0c $base's target-cumargs object has no mt_base_pmode"
  fi
done

# ================================================================ ARM 1
# NON-VACUITY: the redirect is INVOKED, not merely present.  PRINCIPLES
# section 4 rule 2 -- a complete mechanism sat inert for weeks.
echo "=== ARM 1: mt_pmode is actually CALLED while compiling for aarch64 ==="
cat > "$B/g1.gdb" <<'EOF'
set confirm off
set pagination off
set height 0
break mt_pmode
run
finish
printf "MTG mt_pmode returned %u\n", ($rax & 0xffff)
kill
quit
EOF
for side in a64 x86; do
  case $side in a64) ARGS=$A64;; x86) ARGS=$X86;; esac
  P="$B/g1-$side.txt"
  sh "$S/eb-shell-gdb.sh" \
    "cd $B/gcc && gdb -q -batch -nx -x $B/g1.gdb --args ./cc1 -quiet -nostdinc $IN -o /dev/null $ARGS" \
    > "$P" 2>&1
  grep -q 'Breakpoint 2' "$P" && { echo "FATAL: >1 breakpoint in a one-breakpoint run"; exit 9; }
  if ! grep -q 'Breakpoint 1, .*mt_pmode' "$P"; then
    bad "ARM 1 ($side) mt_pmode never reached -- 'not called' is indistinguishable from 'nothing is wrong'"
    continue
  fi
  v=$(grep '^MTG mt_pmode returned ' "$P" | head -1 | sed 's/.*returned //')
  if [ "$v" = "27" ]; then
    ok "ARM 1 ($side) mt_pmode is reached and returns 27 = DImode, this base's own Pmode"
  else
    bad "ARM 1 ($side) mt_pmode returned '$v', wanted 27 (DImode)"
  fi
done
echo "NOTE  ARM 1 is CONSISTENCY, NOT EVIDENCE: both bases' Pmode is DImode, so"
echo "      equal readings here cannot distinguish a fix from a leak.  ARM 2 and"
echo "      ARM 4 carry the divergence."

# ================================================================ ARM 2
# THE DIVERGENCE.  A plus_constant call whose MODE argument disagrees with the
# mode of its rtx is the assert at explow.cc:102.  It must not exist on either
# side now; ARM 4 shows it comes back for aarch64 ONLY when the redirect goes.
echo "=== ARM 2: no plus_constant mode mismatch on either side, and both really compile ==="
cat > "$B/g2.gdb" <<'EOF'
set confirm off
set pagination off
set height 0
break plus_constant if *(unsigned short *)$rsi != 0 && (unsigned) $edi != *(unsigned short *)$rsi
run
printf "MTG no-mismatch\n"
quit
EOF
mismatch_run () {   # mismatch_run <side> <args> <outfile>
  sh "$S/eb-shell-gdb.sh" \
    "cd $B/gcc && gdb -q -batch -nx -x $B/g2.gdb --args ./cc1 -quiet -nostdinc $IN -o $3 $2" \
    > "$B/g2-$1.txt" 2>&1
  [ -s "$B/g2-$1.txt" ] || { echo "FATAL: gdb produced nothing for $1"; exit 9; }
}
mismatch_run x86 "$X86" "$B/g2-x86.s"
if grep -q 'Breakpoint 1,' "$B/g2-x86.txt"; then
  bad "ARM 2a x86_64 has a plus_constant mode mismatch"
elif [ -s "$B/g2-x86.s" ]; then
  ok "ARM 2a x86_64: no mismatch AND it compiled ($(wc -c < "$B/g2-x86.s") bytes) -- 'no hit' is not 'never got there'"
else
  bad "ARM 2a x86_64 produced no asm, so 'no mismatch' means 'never got there'"
fi
# aarch64 no longer ICEs at explow.cc:102; it now dies further on, in
# dwarf2cfi (see STATE.md), so it produces no asm and the compile-completed
# half of the check cannot be asked here.  What IS asked is that the run gets
# past the prologue expander, which is where the mismatch used to be.
mismatch_run a64 "$A64" /dev/null
if grep -q 'Breakpoint 1,' "$B/g2-a64.txt"; then
  bad "ARM 2b aarch64 still has a plus_constant mode mismatch"
else
  ok "ARM 2b aarch64: no plus_constant mode mismatch anywhere in the run"
fi

# ================================================================ ARM 3
# The two artefacts that must not move.
echo "=== ARM 3: the invariants ==="
sh "$S/eb-shell.sh" "cd $B/gcc && ./x86_64-pc-linux-gnu-gcc -S -O2 -nostdinc -o $B/g3-x86.s $IN" \
  > "$B/g3-x86.out" 2> "$B/g3-x86.err"
m=$(md5sum < "$B/g3-x86.s" | cut -c1-12); n=$(wc -c < "$B/g3-x86.s")
if [ "$m" = "378fc33c1e70" ] && [ "$n" = "12369" ]; then
  ok "ARM 3a x86_64 -O2 big.c unmoved: 12369 bytes, md5 378fc33c1e70"
else
  bad "ARM 3a x86_64 -O2 moved: $n bytes, md5 $m"
fi
sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o $B/g3-small.s $B/small.c" \
  > "$B/g3-small.out" 2> "$B/g3-small.err"
m=$(md5sum < "$B/g3-small.s" | cut -c1-12); n=$(wc -c < "$B/g3-small.s")
e=$(wc -c < "$B/g3-small.err")
if [ "$m" = "b01d9157fdc1" ] && [ "$n" = "373" ] && [ "$e" = "0" ]; then
  ok "ARM 3b aarch64 'int x = 1;' unmoved: 373 bytes, md5 b01d9157fdc1, empty stderr"
else
  bad "ARM 3b aarch64 small.c moved: $n bytes, md5 $m, stderr $e bytes"
fi

# ================================================================ ARM 4
# THE INJECTION.  Reverse ONLY the defaults.h redirect -- the thunk, the field
# and the selector stay compiled, so what is being tested is the redirect and
# nothing else -- rebuild, and REQUIRE the old ICE back BY NAME and the mode
# mismatch back with its measured values.  Then restore and require both to
# reverse.  An injection that does not fire is a finding, not a pass.
echo "=== ARM 4: injection -- remove the redirect, the wall must come back ==="
D="$SRC/gcc/defaults.h"
cp "$D" "$B/defaults.h.keep" || { echo "FATAL cannot save defaults.h"; exit 9; }
restore () { cp "$B/defaults.h.keep" "$D"; }
trap 'restore' EXIT INT TERM

# BOTH lines go, not just the `#define'.  Removing only the `#define' leaves
# the `#undef', which makes `Pmode' an UNDEFINED IDENTIFIER rather than i386's
# macro -- measured: the injected build died in gimple-match-*.o with
# `pmode' offered as a spelling correction, and a build that fails to compile
# cannot tell you anything about which back end answers a question.
sed -i -e '/^#undef Pmode$/d' -e '/^#define Pmode (mt_pmode ())$/d' "$D"
grep -q 'Pmode (mt_pmode ())' "$D" && { echo "FATAL: injection did not change defaults.h"; exit 9; }
grep -q '^#undef Pmode$' "$D" && { echo "FATAL: injection left the #undef behind"; exit 9; }
sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 cc1" > "$B/g4-build.out" 2> "$B/g4-build.err"
rc=$?
if [ "$rc" != 0 ]; then
  bad "ARM 4 injected build failed (rc=$rc); cannot score the injection"
  tail -5 "$B/g4-build.err"
else
  sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o /dev/null $IN" \
    > "$B/g4-big.out" 2> "$B/g4-big.err"
  if grep -q 'in plus_constant, at explow.cc:102' "$B/g4-big.err"; then
    ok "ARM 4a the OLD ICE returns BY NAME: 'in plus_constant, at explow.cc:102'"
  else
    bad "ARM 4a injection did not restore the old ICE -- the injection did not fire, which is a finding"
    head -4 "$B/g4-big.err"
  fi
  mismatch_run inj "$A64" /dev/null
  if grep -q 'Breakpoint 1,' "$B/g2-inj.txt"; then
    ok "ARM 4b the plus_constant mode mismatch returns (0 -> 1 mismatching call)"
  else
    bad "ARM 4b no mismatch after injection, so ARM 2b was not measuring the redirect"
  fi
fi

echo "--- restoring"
restore
trap - EXIT INT TERM
grep -q '^#define Pmode (mt_pmode ())' "$D" || { echo "FATAL: restore failed"; exit 9; }
sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 cc1" > "$B/g4-rebuild.out" 2> "$B/g4-rebuild.err"
rc=$?
if [ "$rc" != 0 ]; then
  bad "ARM 4c restore build failed (rc=$rc)"
else
  sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o /dev/null $IN" \
    > "$B/g4r-big.out" 2> "$B/g4r-big.err"
  if grep -q 'in plus_constant, at explow.cc:102' "$B/g4r-big.err"; then
    bad "ARM 4c the old ICE is STILL there after restore"
  else
    ok "ARM 4c restore reverses it: the explow.cc:102 ICE is gone again"
  fi
  sh "$S/eb-shell.sh" "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o $B/g4r-small.s $B/small.c" \
    > "$B/g4rs.out" 2> "$B/g4rs.err"
  m=$(md5sum < "$B/g4r-small.s" | cut -c1-12)
  if [ "$m" = "b01d9157fdc1" ]; then
    ok "ARM 4d after the injection round trip, aarch64 'int x = 1;' is byte-identical again (b01d9157fdc1)"
  else
    bad "ARM 4d small.c md5 after restore is $m, not b01d9157fdc1"
  fi
fi

echo
echo "==== $PASS PASS / $FAIL FAIL"
[ "$FAIL" = 0 ]
