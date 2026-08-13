#!/bin/sh
# #127 GUARDS -- the four `*_POINTER_REGNUM' names plus the two derived
# predicates, and the `enum global_rtl_index' shape change that had to come
# first.
#
# ARM 0 RUNS FIRST and asserts the redirect BY NAME AND BY VALUE, both halves
# of every hunk.  #125's first injection deleted a `#define' and left its
# `#undef', which makes the macro UNDEFINED rather than the primary's, and a
# build that does not compile cannot tell you which back end answers anything.
#
# The arms that cost a rebuild (6 and 7) run last and always restore.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b127}
G="$SRC/gcc"
pass=0; fail=0
ok   () { pass=$((pass+1)); echo "PASS  $*"; }
bad  () { fail=$((fail+1)); echo "FAIL  $*"; }

have () {   # have <file> <literal>   -- grep -F, no pipeline, no -q in a pipe
  grep -F -- "$2" "$1" > /dev/null 2>&1
}

echo "===== ARM 0 -- the redirect, by name and by value, both halves"
for m in STACK_POINTER_REGNUM:mt_stack_pointer_regnum \
         FRAME_POINTER_REGNUM:mt_frame_pointer_regnum \
         HARD_FRAME_POINTER_REGNUM:mt_hard_frame_pointer_regnum \
         ARG_POINTER_REGNUM:mt_arg_pointer_regnum \
         HARD_FRAME_POINTER_IS_FRAME_POINTER:mt_hard_frame_pointer_is_frame_pointer \
         HARD_FRAME_POINTER_IS_ARG_POINTER:mt_hard_frame_pointer_is_arg_pointer; do
  M=${m%%:*}; F=${m##*:}
  if have "$G/defaults.h" "#undef $M"; then ok "defaults.h has '#undef $M'"
  else bad "defaults.h is MISSING '#undef $M'"; fi
  if have "$G/defaults.h" "#define $M"; then ok "defaults.h has '#define $M'"
  else bad "defaults.h is MISSING '#define $M'"; fi
  if have "$G/defaults.h" "$F ())"; then ok "defaults.h redirects $M to $F ()"
  else bad "defaults.h does not name $F in the redirect for $M"; fi
  # A COMPLETE MECHANISM NOTHING INVOKES reads as done and does nothing, so
  # each thunk must be INSTALLED in the table, not merely defined.
  # NOT `,'-anchored: the last entry of the initialiser has no trailing comma,
  # and anchoring on one scored a correctly-installed thunk as missing.  The
  # leading two spaces still keep this to the initialiser and off the
  # definition, which starts in column 1.
  if grep -E "^  mt_base_${F#mt_},?\$" "$G/target-cumargs.cc" > /dev/null 2>&1; then
    ok "mt_base_${F#mt_} is installed in mt_base_frame"
  else bad "mt_base_${F#mt_} is DEFINED BUT NOT INSTALLED in mt_base_frame"; fi
done

echo "===== ARM 1 -- enum global_rtl_index has three unconditional slots"
awk '/^enum global_rtl_index/{e=1} e&&/^};/{e=0} e' "$G/rtl.h" > "$B/g-enum.txt"
if [ ! -s "$B/g-enum.txt" ]; then bad "could not extract the enum -- arm is vacuous"; fi
n=$(grep -c '^ *# *\(if\|elif\|else\|endif\)' "$B/g-enum.txt")
if [ "$n" = 0 ]; then ok "enum body contains no preprocessor conditional (was 6 lines)"
else bad "enum body still has $n preprocessor conditional line(s) -- shape is still per-target"; fi
for k in GR_STACK_POINTER GR_FRAME_POINTER GR_HARD_FRAME_POINTER GR_ARG_POINTER; do
  c=$(grep -c "  $k," "$B/g-enum.txt")
  if [ "$c" = 1 ]; then ok "$k has exactly one unconditional slot"
  else bad "$k appears $c times as an unconditional slot (want 1)"; fi
done
if grep -F 'GR_ARG_POINTER = GR_' "$B/g-enum.txt" > /dev/null 2>&1; then
  bad "GR_ARG_POINTER is still aliased at the ENUM level"
else ok "no enum-level aliasing remains"; fi

echo "===== ARM 2 -- init_emit_regs does the aliasing in the DATA"
if have "$G/emit-rtl.cc" "hard_frame_pointer_rtx = frame_pointer_rtx;"; then
  ok "init_emit_regs shares one rtx for hard-frame == frame"
else bad "init_emit_regs does NOT share the rtx for hard-frame == frame"; fi
if have "$G/emit-rtl.cc" "arg_pointer_rtx = frame_pointer_rtx;"; then
  ok "init_emit_regs shares one rtx for arg == frame"
else bad "init_emit_regs does NOT share the rtx for arg == frame"; fi
if have "$G/emit-rtl.cc" "arg_pointer_rtx = hard_frame_pointer_rtx;"; then
  ok "init_emit_regs shares one rtx for arg == hard-frame"
else bad "init_emit_regs does NOT share the rtx for arg == hard-frame"; fi

echo "===== ARM 3 -- no '#if' arithmetic on the six survives in shared code"
# NO --include FILTER.  PRINCIPLES: a filter list has excluded the answer
# before, and this arm is establishing a ZERO.
( cd "$G" && grep -rn -E '^[[:space:]]*#[[:space:]]*(if|elif)' \
     --exclude-dir=config --exclude-dir=testsuite --exclude-dir=gcc-interface \
     . ) > "$B/g-ifs.txt" 2>/dev/null
if [ ! -s "$B/g-ifs.txt" ]; then bad "the '#if' sweep read EMPTY -- arm is vacuous"; fi
grep -E 'STACK_POINTER_REGNUM|FRAME_POINTER_REGNUM|ARG_POINTER_REGNUM|HARD_FRAME_POINTER_IS' \
     "$B/g-ifs.txt" > "$B/g-ifs-hit.txt" 2>/dev/null
# `#ifdef'/`#if defined' are FINE -- the names stay defined.  Only arithmetic
# is fatal, so filter those out and require nothing left.
# `#ifdef X' / `#ifndef X' have no space before the name and `#if defined'
# starts with a `d', so `#if <non-d>' selects exactly the arithmetic lines.
grep -E '#[[:space:]]*if[[:space:]]+[^d]' "$B/g-ifs-hit.txt" > "$B/g-ifs-arith.txt" 2>/dev/null || true
if [ -s "$B/g-ifs-arith.txt" ]; then
  bad "arithmetic '#if' lines naming the six survive:"; cat "$B/g-ifs-arith.txt"
else ok "no arithmetic '#if' on the six remains outside config/ (the two that existed are now run-time conjuncts)"; fi
# And the non-vacuity of THAT zero: the `#ifdef' hit must still be there, or
# the sweep is matching nothing at all for an unrelated reason.
if grep -F 'HARD_FRAME_POINTER_REGNUM' "$B/g-ifs-hit.txt" > /dev/null 2>&1; then
  ok "the sweep is non-vacuous: reginfo.cc's '#ifdef HARD_FRAME_POINTER_REGNUM' is still found"
else bad "the sweep found NOTHING at all -- the zero above is an instrument failure"; fi

echo "===== ARM 4 -- the divergence in the running cc1 (t127-cause.sh)"
# RE-RUN t127-dbg.sh HERE, exactly as #126's ARM 2 had to.  ARM 6 and ARM 7
# below both relink cc1 with the ordinary `-g0' flags, so a SECOND run of this
# script finds gdb with "No symbol table is loaded" and scores the divergence
# as unreadable -- for a reason belonging entirely to the previous run.  That
# is what happened the first time, and it is not a code fact.
sh "$S/t127-dbg.sh" > "$B/g-arm4-dbg.out" 2>&1
if sh "$S/t127-cause.sh" > "$B/g-cause.out" 2>&1; then
  ok "t127-cause.sh PASS -- 31/64/29/65 vs 7/19/6/16, eight readings, all four pairs differ"
else bad "t127-cause.sh FAILED"; tail -20 "$B/g-cause.out"; fi

echo "===== ARM 5 -- the byte invariants that must NOT move"
sh "$S/t127-state.sh" g5 > "$B/g-state.out" 2>&1
x=$(grep -m1 'x86_64 -O2' "$B/g-state.out")
s=$(grep -m1 'int x = 1;' "$B/g-state.out")
case "$x" in *"bytes=12369"*"md5=378fc33c1e70"*) ok "x86_64 -O2 big.c unmoved: $x";;
  *) bad "x86_64 -O2 big.c MOVED: $x";; esac
case "$s" in *"bytes=373"*"md5=b01d9157fdc1"*) ok "aarch64 'int x = 1;' byte-identical: $s";;
  *) bad "aarch64 'int x = 1;' MOVED: $s";; esac

echo "===== ARM 6 -- FORCE THE ALIASING AND READ THE POINTERS"
# The invariant rtl.h states is about RTX IDENTITY, and neither configured base
# aliases any of the three pointers (i386 7/19/6/16, aarch64 31/64/29/65), so
# the `==' half of it CANNOT be observed on this machine without forcing it.
# ARM 4 measures the `!=' half on both bases; this measures the `==' half by
# making i386's hard frame pointer BE its frame pointer in the thunk, which is
# the one place a per-configuration answer legitimately lives.
#
# This is a MEASUREMENT, not a fix, and it is reverted unconditionally.
CU="$G/target-cumargs.cc"
cp "$CU" "$B/g-cumargs.orig"
restore6 () { cp "$B/g-cumargs.orig" "$CU"; }
trap 'restore6' EXIT INT TERM
sed -i 's|^  return (unsigned int) HARD_FRAME_POINTER_REGNUM;$|  return (unsigned int) FRAME_POINTER_REGNUM; /* ARM6 FORCED ALIAS */|' "$CU"
if have "$CU" "ARM6 FORCED ALIAS"; then
  ok "ARM 6 injection took effect in the source (checked, not assumed)"
  sh "$S/t127-gccbuild.sh" cc1 > "$B/g-arm6-build.out" 2>&1
  if [ $? = 0 ]; then
    sh "$S/t127-dbg.sh" > "$B/g-arm6-dbg.out" 2>&1
    sh "$S/t127-cause.sh" > "$B/g-arm6-cause.out" 2>&1
    a=$(grep -m1 'MT127 x86 fp_eq_hfp=' "$B/g-arm6-cause.out" | sed 's/.*=//')
    ph=$(grep -m1 'MT127 x86 p_hfp=' "$B/g-arm6-cause.out" | sed 's/.*=//')
    pf=$(grep -m1 'MT127 x86 p_fp='  "$B/g-arm6-cause.out" | sed 's/.*=//')
    hr=$(grep -m1 'MT127 x86 hfp_regno=' "$B/g-arm6-cause.out" | sed 's/.*=//')
    if [ -z "$a" ]; then bad "ARM 6 read nothing -- vacuous, not a result"
    elif [ "$a" = 1 ] && [ -n "$pf" ] && [ "$pf" = "$ph" ] && [ "$hr" = 19 ]; then
      ok "ARM 6: with hfp forced to 19, x86_64 hard_frame_pointer_rtx IS frame_pointer_rtx ($pf), fp_eq_hfp=1 -- the rtl.h invariant holds through the DATA"
    else
      bad "ARM 6: forced alias did NOT produce one rtx object (fp_eq_hfp=$a hfp_regno=$hr p_fp=$pf p_hfp=$ph)"
    fi
  else bad "ARM 6 build failed"; tail -5 "$B/g-arm6-build.out"; fi
else bad "ARM 6 injection did NOT change the source -- arm is vacuous"; fi
restore6
trap - EXIT INT TERM
if have "$CU" "ARM6 FORCED ALIAS"; then bad "ARM 6 did not restore"; else ok "ARM 6 restored"; fi

echo "===== ARM 7 -- INJECTION: remove ONLY the defaults.h redirect"
# Thunks, fields and selectors stay compiled; only the six redirect hunks go.
# The arm requires the OLD WRONG BEHAVIOUR back BY NAME -- and note what that
# is here.  Before this change aarch64 did NOT ICE on `int g (int a)
# { return a + 1; }'; it COMPILED, emitting `str x19, [x7, -32]!' -- i386's
# STACK_POINTER_REGNUM 7 and FRAME_POINTER_REGNUM 19 used as aarch64's stack
# and frame pointers.  A silently wrong answer, exit 0.  So the injection must
# bring back the x7/x19 prologue AND the old big.c ICE site by name.
D="$G/defaults.h"
cp "$D" "$B/g-defaults.orig"
restore7 () { cp "$B/g-defaults.orig" "$D"; }
trap 'restore7' EXIT INT TERM
# awk, NOT python3: python3 is not in the DEVSHELL package set, and the first
# version of this arm called it, got "command not found", injected NOTHING and
# then measured the UNINJECTED tree.  Every downstream reading was of the fixed
# compiler.  The half-applied check below is what caught it -- had this arm
# only checked "did the build still work", it would have reported a clean pass
# on an injection that never happened.
awk '
  /^#undef (STACK_POINTER_REGNUM|FRAME_POINTER_REGNUM|HARD_FRAME_POINTER_REGNUM|ARG_POINTER_REGNUM|HARD_FRAME_POINTER_IS_FRAME_POINTER|HARD_FRAME_POINTER_IS_ARG_POINTER)$/ {
    skip = 1; next
  }
  skip == 1 {
    # the `#define` line, plus any backslash continuations of it
    if ($0 ~ /\\$/) { skip = 2 } else { skip = 0 }
    next
  }
  skip == 2 {
    if ($0 !~ /\\$/) { skip = 0 }
    next
  }
  { print }
' "$B/g-defaults.orig" > "$D"
# ASSERT THE INJECTION PRODUCED THE STATE INTENDED -- BOTH halves of every
# hunk gone.  Half a hunk leaves the macro UNDEFINED, not the primary's.
inj=0
for m in STACK_POINTER_REGNUM FRAME_POINTER_REGNUM HARD_FRAME_POINTER_REGNUM \
         ARG_POINTER_REGNUM HARD_FRAME_POINTER_IS_FRAME_POINTER \
         HARD_FRAME_POINTER_IS_ARG_POINTER; do
  if have "$D" "#undef $m"; then echo "  injection left '#undef $m'"; inj=1; fi
  if have "$D" "#define $m (mt_"; then echo "  injection left the '#define $m' redirect"; inj=1; fi
done
if [ $inj = 0 ]; then ok "ARM 7 injection removed BOTH halves of all six hunks"
else bad "ARM 7 injection is HALF-APPLIED -- would test the wrong thing"; fi

sh "$S/t127-gccbuild.sh" multi-target-objs cc1 lto1 > "$B/g-arm7-build.out" 2>&1
rc7=$?
if [ $rc7 = 0 ]; then
  ok "ARM 7 injected tree still builds (an injection that does not compile measures nothing)"
  sh "$S/t127-fn.sh" g7 > "$B/g-arm7-fn.out" 2>&1
  sh "$S/t127-state.sh" g7 > "$B/g-arm7-state.out" 2>&1
  addline=$(grep -m1 '^add  aarch64' "$B/g-arm7-fn.out")
  case "$addline" in *COMPILED*)
      ok "ARM 7: aarch64 'a + 1' is back to compiling instead of ICEing: $addline";;
    *) bad "ARM 7: expected the old exit-0 behaviour back, got: $addline";;
  esac
  if have "$B/g7-add-aarch64-unknown-linux-gnu.s" ", [x7, -32]!"; then
    ok "ARM 7: the WRONG CODE is back BY NAME -- 'str x19, [x7, -32]!', i386's regs 7 and 19 as aarch64's stack and frame pointers"
  else bad "ARM 7: the x7 prologue did NOT return; the injection did not restore the leak"
       grep -m4 'x7\|x19\|sp' "$B/g7-add-aarch64-unknown-linux-gnu.s"; fi
  bigsite=$(grep -m1 'big.c site:' "$B/g-arm7-state.out")
  case "$bigsite" in *"extract_insn, at recog.cc:2890"*)
      ok "ARM 7: the old big.c ICE is back BY NAME: $bigsite";;
    *) bad "ARM 7: big.c did not return to the old site: $bigsite";;
  esac
else bad "ARM 7 injected build FAILED rc=$rc7"; tail -8 "$B/g-arm7-build.out"; fi

restore7
trap - EXIT INT TERM
if have "$D" "#define STACK_POINTER_REGNUM (mt_stack_pointer_regnum ())"; then
  ok "ARM 7 restored the redirect"
else bad "ARM 7 did NOT restore defaults.h"; fi
sh "$S/t127-gccbuild.sh" multi-target-objs cc1 lto1 > "$B/g-arm7-restore.out" 2>&1
if [ $? = 0 ]; then ok "ARM 7 restore rebuild rc=0"; else bad "ARM 7 restore rebuild FAILED"; fi
sh "$S/t127-state.sh" g7r > "$B/g-arm7-restate.out" 2>&1
x=$(grep -m1 'x86_64 -O2' "$B/g-arm7-restate.out")
s=$(grep -m1 'int x = 1;' "$B/g-arm7-restate.out")
b=$(grep -m1 'big.c site:' "$B/g-arm7-restate.out")
case "$x" in *"md5=378fc33c1e70"*) ok "after restore, x86_64 -O2 back to 378fc33c1e70";;
  *) bad "after restore, x86_64 -O2 is $x";; esac
case "$s" in *"md5=b01d9157fdc1"*) ok "after restore, 'int x = 1;' back to b01d9157fdc1";;
  *) bad "after restore, 'int x = 1;' is $s";; esac
case "$b" in *"final_scan_insn_1, at final.cc:2789"*) ok "after restore, big.c back at final.cc:2789";;
  *) bad "after restore, big.c is at: $b";; esac

echo "================================================================"
echo "t127-guards.sh: $pass PASS / $fail FAIL"
exit $fail
