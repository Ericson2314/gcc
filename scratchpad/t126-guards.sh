#!/bin/sh
# #126 -- guards for the DWARF register-numbering conversion.
#
# ARM 0 runs FIRST and asserts the CONTENT of the redirect by name and value.
# PRINCIPLES section 4 rule 7: a generator that ran, exited 0 and changed
# nothing passed every check on exit status, existence, timestamp and
# non-emptiness.  Nothing here is generated, but the same rule applies to an
# edit that half-landed -- #125's first injection deleted a `#define' and left
# the matching `#undef', which makes the macro UNDEFINED rather than the
# primary's, and that build died somewhere else entirely.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b126}
D=$SRC/gcc/defaults.h
CFG=$B/lib/gcc/17.0.0
A64="-mlittle-endian -mabi=lp64 -ftarget-config=$CFG/aarch64-unknown-linux-gnu/specs-config"
X64="-ftarget-config=$CFG/x86_64-pc-linux-gnu/specs-config"
P=0; F=0
ok  () { P=$((P+1)); echo "PASS $*"; }
bad () { F=$((F+1)); echo "FAIL $*"; }

echo "=============== ARM 0: the redirect exists, BY NAME AND BY VALUE ==="
for pair in \
  'DEBUGGER_REGNO(REGNO) (mt_debugger_regno ((unsigned int) (REGNO)))' \
  'DWARF_FRAME_REGNUM(REG) (mt_dwarf_frame_regnum ((unsigned int) (REG)))' \
  'DWARF_FRAME_REGISTERS (mt_dwarf_frame_registers ())' ; do
  name=${pair%%[ (]*}
  if grep -qF "#define $pair" "$D"; then ok "ARM0 defaults.h defines $name to its selector, verbatim"
  else bad "ARM0 defaults.h does NOT define $name to its selector"; fi
  # the `#undef' must be there too: without it the `#define' is a redefinition
  # of the primary's macro and the compiler warns rather than obeys.
  if grep -qx "#undef $name" "$D"; then ok "ARM0 defaults.h has #undef $name"
  else bad "ARM0 defaults.h missing #undef $name"; fi
done
for sym in mt_debugger_regno mt_dwarf_frame_regnum mt_dwarf_frame_registers; do
  grep -q "extern unsigned int $sym" "$SRC/gcc/target-frame.h" \
    && ok "ARM0 target-frame.h declares $sym" || bad "ARM0 target-frame.h lacks $sym"
  grep -q "^$sym (" "$SRC/gcc/target-cumargs-select.cc" \
    && ok "ARM0 target-cumargs-select.cc defines $sym" || bad "ARM0 selector $sym missing"
done
for sym in mt_base_debugger_regno mt_base_dwarf_frame_regnum mt_base_dwarf_frame_registers; do
  grep -q "^$sym (" "$SRC/gcc/target-cumargs.cc" \
    && ok "ARM0 target-cumargs.cc defines $sym" || bad "ARM0 thunk $sym missing"
  grep -qE "^  $sym,?$" "$SRC/gcc/target-cumargs.cc" \
    && ok "ARM0 $sym is INSTALLED in mt_base_frame" \
    || bad "ARM0 $sym compiled but NOT installed in the table (mechanism present, nothing invokes it)"
done

echo
echo "=============== ARM 1: the BOUND CHECK is present, and is against the"
echo "=============== BASE's own FIRST_PSEUDO_REGISTER, not the union's ==="
if grep -q 'regno >= (unsigned int) FIRST_PSEUDO_REGISTER' "$SRC/gcc/target-cumargs.cc"; then
  ok "ARM1 the thunk range-tests against FIRST_PSEUDO_REGISTER"
else
  bad "ARM1 no range test -- the out-of-bounds read is back"
fi
if grep -q 'return INVALID_REGNUM;' "$SRC/gcc/target-cumargs.cc"; then
  ok "ARM1 out-of-range answers INVALID_REGNUM (and not 0, which is a real register on both bases)"
else
  bad "ARM1 out-of-range answer is not INVALID_REGNUM"
fi
# NOT a bare grep for the name: the first version of this check matched the
# COMMENT that explains why the test is not here, and reported FAIL.  A guard
# that cannot tell code from prose is the instrument being wrong, not the code
# -- so it now looks for an actual comparison.
if grep -qE '^[^*/]*if *\(.*FIRST_PSEUDO_REGISTER' "$SRC/gcc/target-cumargs-select.cc"; then
  bad "ARM1 the SELECTOR tests FIRST_PSEUDO_REGISTER in code -- that is the UNION width there, and such a test passes on exactly the inputs the real one must reject"
else
  ok "ARM1 the selector does NOT second-guess the bound at the union width (comment-only mention)"
fi
for pair in 'debugger_regno (regno)' 'dwarf_frame_regnum (regno)' 'dwarf_frame_registers ()'; do
  grep -qF "return mt_frame ()->$pair;" "$SRC/gcc/target-cumargs-select.cc" \
    && ok "ARM1 selector for $pair is a pass-through to the selected base" \
    || bad "ARM1 selector for $pair is not a plain pass-through"
done

echo
# ARM 2 reads values by NAME out of target-cumargs-select.o, so that object
# must carry debug info.  ARM 4 rebuilds it at the tree's normal `-g0', so a
# second run of this script would otherwise find ARM 2 vacuous for a reason
# that is about the previous run and not about the code.
echo
echo "  (re-adding debug info to the two objects ARM 2 reads by name)"
sh "$S/t126-dbg.sh" > "$B/g2dbg.out" 2>&1
echo "  t126-dbg.sh: $(head -1 "$B/g2dbg.out")"

echo
echo "=============== ARM 2: THE DIVERGENCE, read out of the RUNNING cc1 ==="
echo "  ONE breakpoint per run.  The breakpoint gdb ITSELF reports is printed"
echo "  and matched against the function under test before any value is scored."
echo "  \`mt_pmode' is the breakpoint rather than anything in dwarf2cfi.cc"
echo "  because aarch64 does not yet reach the dwarf2 frame pass on this branch"
echo "  (it now dies at recog.cc:2890, the TENTH wall) -- so a breakpoint there"
echo "  would never fire and \"no reading\" would look like \"no divergence\"."
cat > "$B/g2.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break mt_pmode
run
info breakpoints
printf "MT126G dwarf_frame_registers=%u\n", mt_dwarf_frame_registers ()
printf "MT126G debugger_regno_16=%u\n", mt_debugger_regno (16)
printf "MT126G dwarf_frame_regnum_30=%u\n", mt_dwarf_frame_regnum (30)
printf "MT126G out_of_range_94=%u\n", mt_debugger_regno (94)
kill
quit
EOF
for t in a64 x64; do
  case $t in a64) TF=$A64;; x64) TF=$X64;; esac
  sh "$S/eb-shell-gdb.sh" \
    "cd $B/gcc && ulimit -v 4000000 && gdb -q -batch -nx -x $B/g2.cmds --args ./cc1 -quiet -nostdinc $B/big.c -o /dev/null $TF" \
    > "$B/g2-$t.out" 2>&1
  if grep -q 'Breakpoint 1, mt_pmode' "$B/g2-$t.out"; then
    ok "ARM2 $t: gdb reports the breakpoint in mt_pmode (frame matched)"
  else
    bad "ARM2 $t: gdb did not report a stop in mt_pmode -- readings below are NOT scored"
    tail -4 "$B/g2-$t.out"; continue
  fi
  grep MT126G "$B/g2-$t.out" | sed "s/^/    $t: /"
done
# Score the divergence explicitly.  Equal readings here cannot distinguish a
# fix from a leak, so this arm is only evidence if the two bases DIFFER.
va=$(grep -h 'MT126G' "$B/g2-a64.out" 2>/dev/null | sort)
vx=$(grep -h 'MT126G' "$B/g2-x64.out" 2>/dev/null | sort)
if [ -z "$va" ] || [ -z "$vx" ]; then
  bad "ARM2 VACUOUS: one side produced no readings at all"
elif [ "$va" = "$vx" ]; then
  bad "ARM2 both bases read IDENTICALLY -- that is 'everyone got the same new answer', not a fix"
else
  ok "ARM2 the two bases DIVERGE on these readings"
fi
# and the specific values, so a divergence in the wrong direction is not banked
grep -q 'dwarf_frame_registers=97' "$B/g2-a64.out" 2>/dev/null \
  && ok "ARM2 aarch64 DWARF_FRAME_REGISTERS = 97 (aarch64.h:832)" \
  || bad "ARM2 aarch64 DWARF_FRAME_REGISTERS is not 97"
grep -q 'dwarf_frame_registers=17' "$B/g2-x64.out" 2>/dev/null \
  && ok "ARM2 x86_64 DWARF_FRAME_REGISTERS = 17 (i386.h:997)" \
  || bad "ARM2 x86_64 DWARF_FRAME_REGISTERS is not 17"
grep -q 'debugger_regno_16=16' "$B/g2-a64.out" 2>/dev/null \
  && ok "ARM2 aarch64 x16 -> DWARF 16 (was IGNORED_DWARF_REGNUM = 4294967294)" \
  || bad "ARM2 aarch64 x16 does not map to DWARF 16"
grep -q 'debugger_regno_16=4294967294' "$B/g2-x64.out" 2>/dev/null \
  && ok "ARM2 x86_64 regno 16 still IGNORED_DWARF_REGNUM -- i386 keeps ITS answer" \
  || bad "ARM2 x86_64 regno 16 is no longer IGNORED_DWARF_REGNUM (both-sided evidence lost)"
grep -q 'out_of_range_94=4294967295' "$B/g2-x64.out" 2>/dev/null \
  && ok "ARM2 x86_64 regno 94 (union width, past i386's 92) -> INVALID_REGNUM, not an out-of-bounds read" \
  || bad "ARM2 x86_64 regno 94 did not answer INVALID_REGNUM"

echo
echo "=============== ARM 3: the artefacts that must not move ==="
sh "$S/t126-state.sh" guard > "$B/g3.out" 2>&1
grep -q 'int x = 1;  rc=0  bytes=373  stderr_bytes=0  md5=b01d9157fdc1' "$B/g3.out" \
  && ok "ARM3 aarch64 \`int x = 1;' still 373 bytes, md5 b01d9157fdc1, empty stderr" \
  || { bad "ARM3 aarch64 small.c MOVED"; grep 'int x' "$B/g3.out"; }
grep -q 'x86_64 -O2 rc=0  bytes=12369  md5=378fc33c1e70' "$B/g3.out" \
  && ok "ARM3 x86_64 -O2 big.c still 12369 bytes, md5 378fc33c1e70" \
  || { bad "ARM3 x86_64 -O2 MOVED"; grep 'x86_64' "$B/g3.out"; }
grep -q 'big.c site: in extract_insn, at recog.cc:2890' "$B/g3.out" \
  && ok "ARM3 aarch64 big.c is past the SIGKILL and at the NEXT wall (recog.cc:2890)" \
  || { bad "ARM3 aarch64 big.c is not at the expected next wall"; grep 'big.c site' "$B/g3.out"; }

echo
echo "=============== ARM 4: THE INJECTION.  Remove ONLY the defaults.h"
echo "=============== redirect -- thunks, fields and selectors stay compiled --"
echo "=============== and require the OLD failure back BY NAME. ==="
cp "$D" "$B/defaults.h.orig" || exit 9
# Delete the six lines as THREE PAIRS.  #125's first injection deleted a
# `#define' and left its `#undef', which makes the macro undefined rather than
# the primary's; the build then died in an unrelated file and proved nothing.
sed -e '/^#undef DEBUGGER_REGNO$/,+1d' \
    -e '/^#undef DWARF_FRAME_REGNUM$/,+1d' \
    -e '/^#undef DWARF_FRAME_REGISTERS$/,+1d' \
    "$B/defaults.h.orig" > "$D"
inj_ok=1
for name in DEBUGGER_REGNO DWARF_FRAME_REGNUM DWARF_FRAME_REGISTERS; do
  if grep -qx "#undef $name" "$D" || grep -q "mt_$(echo $name | tr A-Z a-z)" "$D"; then
    bad "ARM4 injection left half of the $name hunk behind -- the macro would be UNDEFINED, not the primary's"
    inj_ok=0
  fi
done
[ $inj_ok = 1 ] && ok "ARM4 injection removed BOTH lines of all three hunks (the state I intended)"

TAG=inj sh "$S/t126-gccbuild.sh" multi-target-objs cc1 lto1 > "$B/g4build.out" 2>&1
echo "  injected build: $(head -1 "$B/g4build.out")"
sh "$S/t126-state.sh" inj > "$B/g4.out" 2>&1
if grep -q 'cc1 terminated by signal 9' "$B/g4.out"; then
  ok "ARM4 the OLD failure is back BY NAME: 'cc1 terminated by signal 9'"
else
  bad "ARM4 the old failure did NOT return -- the injection proves nothing"; grep 'big.c site' "$B/g4.out"
fi
# `column' BY REGISTER, not by name.  The injected rebuild above recompiles
# dwarf2cfi.o at the tree's normal `-g0', so the debug info t126-dbg.sh added
# is gone by this point and a by-name condition errors out with "No symbol
# table is loaded" -- which the first version of this arm scored as "the column
# did not return", i.e. a FAIL for a reason that had nothing to do with the
# code.  `column' is the second argument of
# `update_row_reg_save (dw_cfi_row *, unsigned, dw_cfi_ref)', so SysV puts it
# in %esi.  This is #125's t125-hang5 reading, kept because it needs no debug
# info at all.
cat > "$B/g4col.cmds" <<'EOF'
set confirm off
set pagination off
set height 0
break update_row_reg_save if (unsigned) $esi > 1000
run
info breakpoints
printf "MT126G4 column=%u\n", (unsigned) $esi
kill
quit
EOF
sh "$S/eb-shell-gdb.sh" \
  "cd $B/gcc && ulimit -v 4000000 && gdb -q -batch -nx -x $B/g4col.cmds --args ./cc1 -quiet -nostdinc $B/big.c -o /dev/null $A64" \
  > "$B/g4col.out" 2>&1
if grep -q 'Breakpoint 1, update_row_reg_save\|in update_row_reg_save' "$B/g4col.out"; then
  ok "ARM4 gdb reports the stop in update_row_reg_save (frame matched)"
else
  bad "ARM4 gdb did not stop in update_row_reg_save -- the column reading is NOT scored"
fi
if grep -q 'MT126G4 column=4294967294' "$B/g4col.out"; then
  ok "ARM4 the absurd column is back BY VALUE: 4294967294 = IGNORED_DWARF_REGNUM"
else
  bad "ARM4 the 4294967294 column did not return"; tail -4 "$B/g4col.out"
fi

echo "  --- RESTORE"
cp "$B/defaults.h.orig" "$D" || exit 9
grep -qF '#define DEBUGGER_REGNO(REGNO) (mt_debugger_regno ((unsigned int) (REGNO)))' "$D" \
  && ok "ARM4 defaults.h restored (redirect back, verbatim)" || bad "ARM4 RESTORE FAILED"
TAG=res sh "$S/t126-gccbuild.sh" multi-target-objs cc1 lto1 > "$B/g4rbuild.out" 2>&1
echo "  restored build: $(head -1 "$B/g4rbuild.out")"
sh "$S/t126-state.sh" res > "$B/g4r.out" 2>&1
grep -q 'cc1 terminated by signal 9' "$B/g4r.out" \
  && bad "ARM4 RESTORE did not reverse the failure" \
  || ok "ARM4 restore reverses it: no SIGKILL"
grep -q 'int x = 1;  rc=0  bytes=373  stderr_bytes=0  md5=b01d9157fdc1' "$B/g4r.out" \
  && ok "ARM4 aarch64 \`int x = 1;' byte-identical after the injection round trip" \
  || { bad "ARM4 small.c moved across the round trip"; grep 'int x' "$B/g4r.out"; }
grep -q 'x86_64 -O2 rc=0  bytes=12369  md5=378fc33c1e70' "$B/g4r.out" \
  && ok "ARM4 x86_64 -O2 byte-identical after the injection round trip" \
  || { bad "ARM4 x86_64 moved across the round trip"; grep 'x86_64' "$B/g4r.out"; }

echo
echo "=============== $P PASS / $F FAIL ==============="
[ $F = 0 ] || exit 1
