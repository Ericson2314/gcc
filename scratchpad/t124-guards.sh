#!/bin/sh
# #124 -- acceptance arms for the REGISTER-ELIMINATION TABLE
# (ELIMINABLE_REGS, RELOAD_ELIMINABLE_REGS, INITIAL_ELIMINATION_OFFSET, and
#  the NUM_ELIMINABLE_REGS bound derived from them).
#
# WHAT THE INSTRUMENT NAMED AND WHAT IT DID NOT.  `nm -uC ira.o' reports
# `ix86_initial_elimination_offset', so INITIAL_ELIMINATION_OFFSET is the name
# it hands you.  It is a real leak, but ira.cc never spells that macro: what
# ira.cc holds is the TABLE, and it hands i386's register numbers (16, 19, 7,
# 6) to `targetm.can_eliminate', which is aarch64's hook.  aarch64.cc:14153
# asserts the FROM is one of ITS 65 or 64.  Converting only the named macro
# would have left ira.cc walking the primary's four pairs.  So ARM 2 scores
# the REGISTER NUMBERS, not the offset function.
#
# ARM 2 IS TAB-SHAPED and reads the RUNNING cc1 under gdb.  A header probe
# cannot see this family: the probe's base-B context does not define
# MULTI_TARGET_TARGETM_BASE, so defaults.h redirects both sides and the arm
# compares a redirect with itself (PRINCIPLES section 6).
#
# ONE BREAKPOINT PER RUN, and the breakpoint gdb REPORTS is matched against
# the function under test before any value is scored.  #123 lost two arms and
# had a third PASS on a mislabelled read by setting three breakpoints in one
# run.
#
# ARM 4 IS THE INJECTION.  It reverse-applies the whole conversion except the
# two files that only ADD a measurement (multi-target-reg-probe.cc and
# gen-reg-widths.sh), rebuilds, and REQUIRES both the primary's symbol back in
# the eight consumer objects and the OLD ICE back by name.  An injection that
# does not fire is a finding, not a pass.
set -u

S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b124}
CA=$B/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
CX=$B/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
# The eight shared translation units that held the primary's elimination table.
CONSUMERS="ira.o reload1.o lra-eliminations.o rtlanal.o varasm.o stmt.o df-scan.o builtins.o"
# Everything the conversion touched EXCEPT the two pure-measurement files.
REVERT="gcc/defaults.h gcc/target-frame.h gcc/target-cumargs.cc \
gcc/target-cumargs-select.cc gcc/ira.cc gcc/reload1.cc gcc/lra-eliminations.cc \
gcc/rtlanal.cc gcc/varasm.cc gcc/stmt.cc gcc/df-scan.cc gcc/builtins.cc"

pass=0; fail=0
ok ()  { echo "PASS: $*"; pass=$((pass+1)); }
bad () { echo "FAIL: $*"; fail=$((fail+1)); }

sh_run  () { sh "$S/eb-shell.sh" "$1"; }
gdb_run () { sh "$S/eb-shell-gdb.sh" "$1"; }

# ---------------------------------------------------------------- preconditions
cp "$S/big.c" "$B/big.c" || exit 9
for f in "$B/gcc/cc1" "$B/gcc/ira.o" "$CA" "$CX" "$B/big.c"; do
  [ -s "$f" ] || { echo "FATAL precondition: missing or empty $f"; exit 9; }
done
cat > "$B/fn.c" <<'EOF'
/* Must contain a FUNCTION.  A translation unit with no function never reaches
   df_hard_reg_init or ira, so no breakpoint could ever hit and "not hit" would
   read as "the dispatch is fine".  */
int fn (int x) { int a[4]; a[0] = x; return a[0] + x; }
EOF

# ================================================================ ARM 0
# THE UNION BOUND EXISTS AND IS A NUMBER.  gen-reg-widths.sh ran, exited 0 and
# changed NOTHING the first time this was tried, because the `#define' had not
# been added to its heredoc -- a generator succeeding while producing the old
# artefact, which is PRINCIPLES section 4 rule 7 exactly.  So the bound is
# checked by name and by value, in the generated file, not by the script's
# exit status.
echo "=== ARM 0: the union bound is in the generated header ==="
W=$B/gcc/multi-target-reg-widths.h
nb=$(sed -n 's/^#define MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS \([0-9][0-9]*\)$/\1/p' "$W")
if [ -n "$nb" ] && [ "$nb" -ge 1 ]; then
  ok "ARM 0 MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS = $nb in $W"
else
  bad "ARM 0 no numeric MULTI_TARGET_UNION_NUM_ELIMINABLE_REGS in $W (got '$nb')"
fi

# ================================================================ ARM 1
# STATIC, ON THE LINKED OBJECTS.  Both directions, so neither can pass
# vacuously.
echo "=== ARM 1: the eight consumers no longer reference the primary ==="
sh_run "cd $B/gcc && nm -uC $CONSUMERS" > "$B/g1-cons.txt" 2>&1
[ -s "$B/g1-cons.txt" ] || { echo "FATAL non-vacuity: nm read nothing"; exit 9; }
n_ieo=$(grep -c 'ix86_initial_elimination_offset' "$B/g1-cons.txt")
n_other=$(grep -c 'ix86_' "$B/g1-cons.txt")
if [ "$n_other" -lt 1 ]; then
  echo "FATAL non-vacuity: no ix86_ symbol of ANY kind across $CONSUMERS -- a"
  echo "  zero for ix86_initial_elimination_offset would be a claim about the"
  echo "  instrument rather than about the code."
  exit 9
fi
if [ "$n_ieo" -eq 0 ]; then
  ok "ARM 1a ix86_initial_elimination_offset absent from all eight consumers (and $n_other other ix86_ refs still visible, so nm reads)"
else
  bad "ARM 1a ix86_initial_elimination_offset still referenced ($n_ieo)"
fi

sh_run "cd $B/gcc && nm -C cc1" > "$B/g1-nm.txt" 2>&1
[ -s "$B/g1-nm.txt" ] || { echo "FATAL non-vacuity: nm read nothing from cc1"; exit 9; }
miss=
for s in mt_num_eliminable_regs mt_eliminable_from mt_eliminable_to \
         mt_num_reload_eliminable_regs mt_reload_eliminable_from \
         mt_reload_eliminable_to mt_initial_elimination_offset; do
  grep -q "T $s(" "$B/g1-nm.txt" || miss="$miss $s"
done
if [ -z "$miss" ]; then
  ok "ARM 1b all seven mt_ elimination entry points defined in the running cc1"
else
  bad "ARM 1b missing from cc1:$miss"
fi

# ================================================================ ARM 2
echo "=== ARM 2: the running cc1 answers with each base's OWN register numbers ==="
cat > "$B/g.gdb.in" <<'EOF'
set confirm off
set pagination off
set height 0
break @FN@
run
finish
printf "MTPROBE @FN@ = %u\n", ($rax & @MASK@)
kill
quit
EOF

run_probe () {   # run_probe <side> <config> <fn> <mask>
  PF="$B/g2-$1-$3.txt"
  sed -e "s/@FN@/$3/g" -e "s/@MASK@/$4/g" "$B/g.gdb.in" > "$B/g2-$1-$3.gdb"
  gdb_run "cd $B/gcc && gdb -q -batch -x $B/g2-$1-$3.gdb --args ./cc1 -quiet -nostdinc $B/fn.c -o /dev/null -ftarget-config=$2" \
    > "$PF" 2>&1
  [ -s "$PF" ] || { echo "FATAL non-vacuity: gdb produced no output for $1/$3"; exit 9; }
  grep -q "Breakpoint 2" "$PF" && {
    echo "FATAL: more than one breakpoint in a run that must have exactly one"; exit 9; }
}

probe_one () {   # probe_one <side> <config> <fn> <mask> -- REQUIRES a hit
  run_probe "$@"
  grep -q "Breakpoint 1, .*$3" "$PF" || {
    echo "FATAL non-vacuity: gdb never stopped inside $3 for $1."
    echo "  'not hit' is indistinguishable from 'the dispatch is fine'."
    tail -15 "$PF"; exit 9; }
  grep "^MTPROBE $3 = " "$PF" | head -1 | sed 's/.*= //'
}

# THE FIRST CALL IS PAIR 0 FOR BOTH BASES (df_hard_reg_init walks from 0), and
# pair 0 is {ARG_POINTER_REGNUM, STACK_POINTER_REGNUM} in both back ends' own
# ELIMINABLE_REGS -- so the two sides are reading the SAME slot and differ only
# in whose numbering it is.  i386: 16 -> 7.  aarch64: 65 -> 31.
a_from=$(probe_one a64 "$CA" mt_eliminable_from 0xffffffff) || exit 9
x_from=$(probe_one x86 "$CX" mt_eliminable_from 0xffffffff) || exit 9
a_to=$(probe_one a64 "$CA" mt_eliminable_to 0xffffffff) || exit 9
x_to=$(probe_one x86 "$CX" mt_eliminable_to 0xffffffff) || exit 9
a_n=$(probe_one a64 "$CA" mt_num_eliminable_regs 0xffffffff) || exit 9
x_n=$(probe_one x86 "$CX" mt_num_eliminable_regs 0xffffffff) || exit 9
echo "  aarch64: pair0 from=$a_from to=$a_to  n=$a_n"
echo "  x86_64 : pair0 from=$x_from to=$x_to  n=$x_n"

if [ "$a_from" = 65 ] && [ "$x_from" = 16 ]; then
  ok "ARM 2a ELIMINABLE_REGS pair 0 FROM is each base's own ARG_POINTER_REGNUM: aarch64 65 vs x86_64 16 -- both-sided, so this cannot be 'everyone got the same new answer'"
else
  bad "ARM 2a pair0 from: aarch64='$a_from' (want 65) x86_64='$x_from' (want 16)"
fi
if [ "$a_to" = 31 ] && [ "$x_to" = 7 ]; then
  ok "ARM 2b ELIMINABLE_REGS pair 0 TO is each base's own STACK_POINTER_REGNUM: aarch64 31 vs x86_64 7"
else
  bad "ARM 2b pair0 to: aarch64='$a_to' (want 31) x86_64='$x_to' (want 7)"
fi
# CONSISTENCY ONLY, AND SAID SO.  Both bases have four pairs, so this number
# cannot distinguish "each base answered" from "everyone got the primary's".
# It is scored because a count that suddenly disagreed would mean the table and
# the count came from different objects -- not because it is evidence.
if [ "$a_n" = 4 ] && [ "$x_n" = 4 ]; then
  ok "ARM 2c consistency (NOT evidence): both bases report 4 pairs, which is what both back ends' headers say; the length agrees while all four register numbers diverge"
else
  bad "ARM 2c pair count: aarch64='$a_n' x86_64='$x_n' (both should be 4)"
fi

# ================================================================ ARM 3
echo "=== ARM 3: where big.c stops for aarch64, and the two artefacts that must not move ==="
big_site () {
  sh_run "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o /dev/null $B/big.c" \
    > "$B/g3.out" 2> "$B/g3.err"
  if grep -q 'internal compiler error' "$B/g3.err"; then
    grep -m1 'internal compiler error' "$B/g3.err" | sed 's/.*internal compiler error: //'
  elif [ -s "$B/g3.err" ]; then
    echo "OTHER-STDERR"
  else
    echo "NO-ICE"
  fi
}
site=$(big_site)
echo "  big.c site: $site"
case $site in
  *aarch64_can_eliminate*aarch64.cc:14153*)
    bad "ARM 3a big.c still stops at the converted wall -- the table is not reaching ira.cc" ;;
  NO-ICE)
    ok "ARM 3a big.c compiles for aarch64 with no ICE at all" ;;
  *)
    ok "ARM 3a big.c has moved OFF aarch64.cc:14153 to: $site" ;;
esac

printf 'int x = 1;\n' > "$B/small.c"
rm -f "$B/g3-small.s"
sh_run "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o $B/g3-small.s $B/small.c" \
  > "$B/g3-small.out" 2> "$B/g3-small.err"
rc=$?
sz=0; [ -f "$B/g3-small.s" ] && sz=$(wc -c < "$B/g3-small.s")
es=$(wc -c < "$B/g3-small.err")
md=$( [ -f "$B/g3-small.s" ] && md5sum < "$B/g3-small.s" | cut -c1-12 )
if [ $rc -eq 0 ] && [ "$es" -eq 0 ] && [ "$sz" -eq 373 ] && [ "$md" = b01d9157fdc1 ]; then
  ok "ARM 3b aarch64 'int x = 1;' rc=0, empty stderr, 373 bytes, md5 $md -- byte-identical to the pre-edit output measured in this same build dir"
else
  bad "ARM 3b aarch64 'int x = 1;' rc=$rc stderr=$es bytes=$sz md5=$md (want 0 / 0 / 373 / b01d9157fdc1)"
fi

rm -f "$B/g3-x86.s"
sh_run "cd $B/gcc && ./x86_64-pc-linux-gnu-gcc -S -O2 -nostdinc -o $B/g3-x86.s $B/big.c" \
  > "$B/g3-x86.out" 2> "$B/g3-x86.err"
xsz=0; [ -f "$B/g3-x86.s" ] && xsz=$(wc -c < "$B/g3-x86.s")
xmd=$( [ -f "$B/g3-x86.s" ] && md5sum < "$B/g3-x86.s" | cut -c1-12 )
if [ "$xsz" -eq 12369 ] && [ "$xmd" = 378fc33c1e70 ]; then
  ok "ARM 3c x86_64 -O2 big.c unmoved: 12369 bytes, md5 $xmd -- measured before AND after the edit in this same build dir"
else
  bad "ARM 3c x86_64 -O2 big.c MOVED: bytes=$xsz md5=$xmd (want 12369 / 378fc33c1e70)"
fi

# ================================================================ ARM 4
echo "=== ARM 4: injection -- revert the conversion, require the leak to RETURN ==="
INJ=$B/g4.patch
( cd "$SRC" && git diff -- $REVERT ) > "$INJ"
if [ ! -s "$INJ" ]; then
  ( cd "$SRC" && git diff HEAD~1 -- $REVERT ) > "$INJ"
fi
if [ ! -s "$INJ" ]; then
  echo "FATAL: no hunk to reverse-apply, uncommitted or in HEAD~1."
  echo "  This arm asserts NOTHING without it."
  exit 9
fi
echo "  injection hunk: $(wc -l < "$INJ") lines over $(grep -c '^+++ ' "$INJ") files"

restore () {
  ( cd "$SRC" && git apply "$INJ" ) 2>/dev/null
  sh_run "cd $B/gcc && make -j8 multi-target-objs cc1" > "$B/g4-res-build.log" 2>&1
}
trap 'echo "(trap) restoring"; restore' EXIT INT TERM

( cd "$SRC" && git apply -R "$INJ" ) || { echo "FATAL: could not reverse-apply"; exit 9; }
grep -q 'mt_initial_elimination_offset' "$SRC/gcc/defaults.h" && {
  echo "FATAL: the injection did not actually change defaults.h"; exit 9; }

sh_run "cd $B/gcc && make -j8 multi-target-objs cc1" > "$B/g4-inj-build.log" 2>&1
inj_rc=$?
if [ $inj_rc -ne 0 ]; then
  bad "ARM 4 injected build failed (rc=$inj_rc); the arm cannot be scored"
else
  sh_run "cd $B/gcc && nm -uC $CONSUMERS" > "$B/g4-inj-nm.txt" 2>&1
  i_ieo=$(grep -c 'ix86_initial_elimination_offset' "$B/g4-inj-nm.txt")
  if [ "$i_ieo" -ge 1 ]; then
    ok "ARM 4a injection FIRED on the symbol: ix86_initial_elimination_offset is back in the consumers (0 -> $i_ieo)"
  else
    bad "ARM 4a INJECTION DID NOT FIRE -- reverting did not bring the primary's symbol back.  ARM 1a may have been passing for another reason."
  fi
  i_site=$(big_site)
  echo "  injected big.c site: $i_site"
  case $i_site in
    *aarch64_can_eliminate*aarch64.cc:14153*)
      ok "ARM 4b injection FIRED on behaviour: the OLD ICE is back by name ($i_site)" ;;
    *)
      bad "ARM 4b INJECTION DID NOT REPRODUCE THE OLD ICE (got '$i_site').  Without it, ARM 3a does not show this change is what moved the wall." ;;
  esac
fi

trap - EXIT INT TERM
restore
sh_run "cd $B/gcc && nm -uC $CONSUMERS" > "$B/g4-res-nm.txt" 2>&1
r_ieo=$(grep -c 'ix86_initial_elimination_offset' "$B/g4-res-nm.txt")
r_site=$(big_site)
if [ "$r_ieo" -eq 0 ]; then
  ok "ARM 4c RESTORE verified on the symbol: gone again ($i_ieo -> 0)"
else
  bad "ARM 4c RESTORE FAILED: symbol still present ($r_ieo) -- the tree is left injected"
fi
if [ "$r_site" = "$site" ]; then
  ok "ARM 4d RESTORE verified on behaviour: big.c stops where it did before the injection ($r_site)"
else
  bad "ARM 4d after restore big.c stops at '$r_site' but before the injection it stopped at '$site'"
fi

echo
echo "=== $pass PASS / $fail FAIL ==="
[ $fail -eq 0 ]
