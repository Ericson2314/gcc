#!/bin/sh
# #123 -- acceptance arms for the STACK-ALIGNMENT CLOSURE
# (INCOMING_STACK_BOUNDARY, MAX_STACK_ALIGNMENT, MAX_SUPPORTED_STACK_ALIGNMENT,
#  SUPPORTS_STACK_ALIGNMENT).
#
# ARM 2 IS TAB-SHAPED: it reads the RUNNING `cc1' under gdb, not a header probe
# and not an object.  A header probe cannot see this one at all -- the probe's
# base-B context does not define MULTI_TARGET_TARGETM_BASE, so defaults.h
# redirects BOTH sides and the arm compares a redirect with itself (PRINCIPLES
# section 6).  That is exactly why #108's six read as green.
#
# The build is -g0, so gdb has no DWARF: breakpoints are set on ELF symtab
# names and the return value is read out of $rax after `finish'.  #122 lost a
# run to `-g0' silently making a gdb probe read nothing, so every arm below
# carries a NON-VACUITY FATAL that refuses to score when it cannot show it read
# something.
#
# ARM 2 IS BOTH-SIDED ON A DIVERGENT VALUE, DELIBERATELY.
# `mt_incoming_stack_boundary' answers 128 for BOTH bases -- i386's
# ix86_incoming_stack_boundary defaults to 128 and aarch64 falls through
# defaults.h:945 to its PREFERRED_STACK_BOUNDARY, also 128.  An arm resting on
# that name alone would pass while proving nothing, since "both get 128" is
# indistinguishable from "everyone still gets the primary's answer".  So the
# scored values are `max_stack_alignment' (i386: elfos.h's MAX_OFILE_ALIGNMENT,
# 2147483648; aarch64: its STACK_BOUNDARY, 128) and `supports_stack_alignment'
# (true vs FALSE), which differ by a factor of 16 million and by their truth
# value respectively.  The 128/128 coincidence is asserted too, but as a
# consistency check and never as the evidence.
#
# ARM 4 IS THE INJECTION.  It reverse-applies the defaults.h hunk ONLY -- so
# the mt_ thunks stay compiled and only the redirect goes -- rebuilds, and
# REQUIRES the primary's symbol to reappear in cfgexpand.o and the OLD ICE to
# come back by name.  An injection that does not fire is a finding, not a pass.
set -u

S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b123}
CA=$B/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
CX=$B/lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
pass=0; fail=0
ok ()  { echo "PASS: $*"; pass=$((pass+1)); }
bad () { echo "FAIL: $*"; fail=$((fail+1)); }

sh_run () { sh "$S/eb-shell.sh" "$1"; }
gdb_run () {
  sh "$S/eb-shell-gdb.sh" "$1"
}

# ---------------------------------------------------------------- preconditions
for f in "$B/gcc/cc1" "$B/gcc/cfgexpand.o" "$CA" "$CX" "$B/big.c"; do
  [ -s "$f" ] || { echo "FATAL precondition: missing or empty $f"; exit 9; }
done
cat > "$B/fn.c" <<'EOF'
/* Must contain a FUNCTION.  #122 lost a probe run to `int x = 1;' -- a
   translation unit with no function never reaches the passes under test, so
   no breakpoint could ever hit and "not hit" read as "dispatch is fine".  */
int fn (int x) { int a[4]; a[0] = x; return a[0] + x; }
EOF

# ================================================================ ARM 1
# STATIC, ON THE LINKED BINARY.  The primary's symbol must be GONE from the
# shared TU, and the four new entry points must be present.  Both directions,
# so neither can pass vacuously.
echo "=== ARM 1: cfgexpand.o no longer references the primary ==="
sh_run "cd $B/gcc && nm -uC cfgexpand.o" > "$B/g1-cfgexpand.txt" 2>&1
[ -s "$B/g1-cfgexpand.txt" ] || { echo "FATAL non-vacuity: nm read nothing from cfgexpand.o"; exit 9; }
n_isb=$(grep -c 'ix86_incoming_stack_boundary' "$B/g1-cfgexpand.txt")
# Non-vacuity: nm must still be finding OTHER ix86 references in this file, or
# a zero above could just mean the symbol table is empty / the filter is wrong.
n_other=$(grep -c 'ix86_' "$B/g1-cfgexpand.txt")
if [ "$n_other" -lt 1 ]; then
  echo "FATAL non-vacuity: no ix86_ symbol of ANY kind in cfgexpand.o -- a zero"
  echo "  for ix86_incoming_stack_boundary would be a claim about the instrument."
  exit 9
fi
if [ "$n_isb" -eq 0 ]; then
  ok "ARM 1a ix86_incoming_stack_boundary absent from cfgexpand.o (and $n_other other ix86_ refs still visible, so the instrument reads)"
else
  bad "ARM 1a ix86_incoming_stack_boundary still referenced by cfgexpand.o ($n_isb)"
fi

sh_run "cd $B/gcc && nm -C cc1" > "$B/g1-nm.txt" 2>&1
[ -s "$B/g1-nm.txt" ] || { echo "FATAL non-vacuity: nm read nothing from cc1"; exit 9; }
miss=
for s in mt_incoming_stack_boundary mt_max_stack_alignment \
         mt_max_supported_stack_alignment mt_supports_stack_alignment; do
  grep -q "T $s()" "$B/g1-nm.txt" || miss="$miss $s"
done
if [ -z "$miss" ]; then
  ok "ARM 1b all four mt_ entry points defined in the running cc1"
else
  bad "ARM 1b missing from cc1:$miss"
fi

# ================================================================ ARM 2
# BOTH-SIDED, ON THE RUNNING cc1.  Each base must produce ITS OWN answer.
echo "=== ARM 2: the running cc1 answers differently for the two bases ==="
# ONE BREAKPOINT PER RUN, AND THE LABEL COMES FROM GDB RATHER THAN FROM ME.
#
# The first version of this arm set all three breakpoints in one run and then
# narrated `HIT <name>' between `finish' commands, assuming the three would be
# reached in the order they were set.  They are not: `mt_supports_stack_
# alignment' is hit FIRST and repeatedly (record_alignment_for_reg_var), so all
# three printed values were that ONE function's return value under three
# different names.  Two arms then compared the wrong function's answer -- and
# the third, `supports', PASSED, because 0 for aarch64 and 1 for x86_64 is what
# it happened to be reading anyway.  A passing arm on a mislabelled read is
# the false green this project has produced 26 times; recorded here rather
# than quietly fixed.
#
# So: one function per gdb run, and the breakpoint gdb REPORTS is matched
# against the function under test before any value is scored.
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

run_probe () {   # run_probe <side> <config> <fn> <mask>  -- leaves output in $PF
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
  # The stop must be IN the function under test.  This is the check the first
  # version of the arm lacked, and the one that would have caught the mislabel.
  grep -q "Breakpoint 1, .*$3" "$PF" || {
    echo "FATAL non-vacuity: gdb never stopped inside $3 for $1."
    echo "  'not hit' is indistinguishable from 'the dispatch is fine'."
    tail -15 "$PF"; exit 9; }
  grep "^MTPROBE $3 = " "$PF" | head -1 | sed 's/.*= //'
}

# `mt_max_supported_stack_alignment', NOT `mt_max_stack_alignment', and the
# swap is a measured result rather than a preference.  An earlier version of
# this arm probed `MAX_STACK_ALIGNMENT' directly and the non-vacuity FATAL
# fired: outside `config/' that macro has exactly ONE use
# (tree-vect-data-refs.cc:6808), which needs the vectoriser, and aarch64 cannot
# reach it while `big.c'/`fn.c' still ICE in `ira'.  So `MAX_STACK_ALIGNMENT'
# is currently UNCHECKABLE at run time on this machine -- a measured "cannot
# be checked, because X", not a pass.  `MAX_SUPPORTED_STACK_ALIGNMENT' is
# reached on every function, and it diverges by the same 16-million-fold
# margin, because it is the OTHER arm of the same defaults.h:1249 `#ifdef'.
a_msa=$(probe_one a64 "$CA" mt_max_supported_stack_alignment 0xffffffff) || exit 9
x_msa=$(probe_one x86 "$CX" mt_max_supported_stack_alignment 0xffffffff) || exit 9
a_sup=$(probe_one a64 "$CA" mt_supports_stack_alignment 0xff)  || exit 9
x_sup=$(probe_one x86 "$CX" mt_supports_stack_alignment 0xff)  || exit 9
echo "  aarch64: max_supported_stack_alignment=$a_msa supports=$a_sup"
echo "  x86_64 : max_supported_stack_alignment=$x_msa supports=$x_sup"

if [ "$a_msa" = 128 ] && [ "$x_msa" = 2147483648 ]; then
  ok "ARM 2a MAX_SUPPORTED_STACK_ALIGNMENT is each base's own: aarch64 128 (its PREFERRED_STACK_BOUNDARY, defaults.h:1253) vs x86_64 2147483648 (i386's MAX_STACK_ALIGNMENT, defaults.h:1250) -- the two OPPOSITE arms of the '#ifdef' that shared code could not evaluate"
else
  bad "ARM 2a MAX_SUPPORTED_STACK_ALIGNMENT aarch64='$a_msa' (want 128) x86_64='$x_msa' (want 2147483648)"
fi
if [ "$a_sup" = 0 ] && [ "$x_sup" = 1 ]; then
  ok "ARM 2b SUPPORTS_STACK_ALIGNMENT is FALSE for aarch64 and TRUE for x86_64 -- the truth value itself diverges, so this cannot be 'everyone got the same new answer'"
else
  bad "ARM 2b SUPPORTS_STACK_ALIGNMENT aarch64='$a_sup' (want 0) x86_64='$x_sup' (want 1)"
fi

# ARM 2c IS ASYMMETRIC ON PURPOSE, and the asymmetry is the point.
#
# `INCOMING_STACK_BOUNDARY' is 128 for BOTH bases (i386's default and aarch64's
# fall-through to PREFERRED_STACK_BOUNDARY coincide), so an equality arm on its
# value would pass while being unable to tell "each base answered" from
# "everyone still got the primary's".  What DOES distinguish them is whether it
# is asked at all: its only two shared uses are inside `expand_stack_alignment',
# which aarch64 must now RETURN FROM at its second line.  So x86_64 must reach
# it and aarch64 must not.
#
# A "not hit" is only meaningful if the process got PAST the point where the
# call would have been, so the aarch64 side additionally requires evidence that
# expand finished -- the run must reach `ira'.  Without that, an early crash
# would score as the early return.
echo "  -- ARM 2c: asked of x86_64, and correctly NOT asked of aarch64"
x_isb=$(probe_one x86 "$CX" mt_incoming_stack_boundary 0xffffffff) || exit 9
run_probe a64 "$CA" mt_incoming_stack_boundary 0xffffffff
a_hit=$(grep -c "Breakpoint 1, .*mt_incoming_stack_boundary" "$PF")
a_reached_ira=$(grep -c 'ira_setup_eliminable_regset\|pass_ira' "$PF")
echo "     x86_64 value=$x_isb ; aarch64 hits=$a_hit reached-ira=$a_reached_ira"
if [ "$x_isb" = 128 ] && [ "$a_hit" -eq 0 ] && [ "$a_reached_ira" -ge 1 ]; then
  ok "ARM 2c x86_64 asks INCOMING_STACK_BOUNDARY (128); aarch64 never asks it, having returned early from expand_stack_alignment -- and the aarch64 run demonstrably ran ON to ira, so 'not asked' is the early return and not an early crash"
elif [ "$a_reached_ira" -lt 1 ]; then
  bad "ARM 2c UNSCORABLE: the aarch64 run never reached ira, so a missing hit cannot be attributed to the early return"
else
  bad "ARM 2c x86_64 value='$x_isb' (want 128), aarch64 hits=$a_hit (want 0)"
fi

# ================================================================ ARM 3
# WHERE big.c STOPS.  Recorded by name so a move is reported rather than
# assumed, and matched in BOTH ICE shapes (#122's instrument scored a
# reshaped diagnostic as "no ICE at all").
echo "=== ARM 3: where big.c stops for aarch64 ==="
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
  *expand_stack_alignment*cfgexpand.cc:6941*)
    bad "ARM 3 big.c still stops at the converted wall -- the redirect is not reaching cfgexpand.cc" ;;
  NO-ICE)
    ok "ARM 3 big.c compiles for aarch64 with no ICE at all" ;;
  *)
    ok "ARM 3 big.c has moved OFF cfgexpand.cc:6941 to a new place: $site" ;;
esac

echo "=== ARM 3b: aarch64 'int x = 1;' must still work ==="
printf 'int x = 1;\n' > "$B/small.c"
sh_run "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o $B/g3-small.s $B/small.c" \
  > "$B/g3-small.out" 2> "$B/g3-small.err"
rc=$?
sz=$( [ -f "$B/g3-small.s" ] && wc -c < "$B/g3-small.s" || echo 0 )
es=$(wc -c < "$B/g3-small.err")
if [ $rc -eq 0 ] && [ "$es" -eq 0 ] && [ "$sz" -eq 373 ]; then
  ok "ARM 3b aarch64 'int x = 1;' rc=0, empty stderr, 373 bytes -- unchanged"
else
  bad "ARM 3b aarch64 'int x = 1;' rc=$rc stderr=$es bytes bytes=$sz (want rc=0 / 0 / 373)"
fi

# ================================================================ ARM 4
# THE INJECTION.  Reverse-apply the defaults.h hunk only.
echo "=== ARM 4: injection -- revert the redirect, require the leak to RETURN ==="
INJ=$B/g4-defaults.patch
( cd "$SRC" && git diff -- gcc/defaults.h ) > "$INJ"
if [ ! -s "$INJ" ]; then
  echo "FATAL: no uncommitted defaults.h hunk to reverse-apply."
  echo "  If the change is already committed, generate the hunk from the commit"
  echo "  instead; this arm asserts NOTHING without it."
  exit 9
fi

restore () {
  ( cd "$SRC" && git apply "$INJ" ) 2>/dev/null
  sh_run "cd $B/gcc && make -j8 cc1" > "$B/g4-res-build.log" 2>&1
}
trap 'echo "(trap) restoring"; restore' EXIT INT TERM

( cd "$SRC" && git apply -R "$INJ" ) || { echo "FATAL: could not reverse-apply the hunk"; exit 9; }
grep -q 'mt_incoming_stack_boundary ()' "$SRC/gcc/defaults.h" && {
  echo "FATAL: the injection did not actually change defaults.h"; exit 9; }
sh_run "cd $B/gcc && make -j8 cc1" > "$B/g4-inj-build.log" 2>&1
inj_rc=$?
if [ $inj_rc -ne 0 ]; then
  bad "ARM 4 injected build failed (rc=$inj_rc); the arm cannot be scored"
else
  sh_run "cd $B/gcc && nm -uC cfgexpand.o" > "$B/g4-inj-nm.txt" 2>&1
  i_isb=$(grep -c 'ix86_incoming_stack_boundary' "$B/g4-inj-nm.txt")
  if [ "$i_isb" -ge 1 ]; then
    ok "ARM 4a injection FIRED: ix86_incoming_stack_boundary is back in cfgexpand.o (0 -> $i_isb)"
  else
    bad "ARM 4a INJECTION DID NOT FIRE -- reverting the redirect did not bring the primary's symbol back.  That is a finding: ARM 1a may have been passing for another reason."
  fi
  i_site=$(big_site)
  echo "  injected big.c site: $i_site"
  case $i_site in
    *expand_stack_alignment*cfgexpand.cc:6941*)
      ok "ARM 4b injection FIRED on behaviour: the OLD ICE is back by name ($i_site)" ;;
    *)
      bad "ARM 4b INJECTION DID NOT REPRODUCE THE OLD ICE (got '$i_site').  Without it, ARM 3 does not show this change is what moved the wall." ;;
  esac
fi

trap - EXIT INT TERM
restore
sh_run "cd $B/gcc && nm -uC cfgexpand.o" > "$B/g4-res-nm.txt" 2>&1
r_isb=$(grep -c 'ix86_incoming_stack_boundary' "$B/g4-res-nm.txt")
r_site=$(big_site)
if [ "$r_isb" -eq 0 ]; then
  ok "ARM 4c RESTORE verified: ix86_incoming_stack_boundary gone again ($i_isb -> 0)"
else
  bad "ARM 4c RESTORE FAILED: symbol still present ($r_isb) -- the tree is left injected"
fi
if [ "$r_site" = "$site" ]; then
  ok "ARM 4d RESTORE verified on behaviour: big.c stops where it did before the injection ($r_site)"
else
  bad "ARM 4d after restore big.c stops at '$r_site' but before the injection it stopped at '$site'"
fi

echo
echo "=== $pass PASS / $fail FAIL ==="
[ $fail -eq 0 ]
