#!/bin/sh
# #128 GUARDS -- the CONSTRAINT vocabulary.
#
# ARM 0 RUNS FIRST and asserts the GENERATED content by name and by value.  A
# generator that ran, exited 0 and changed nothing is this branch's sharpest
# recorded false green (PRINCIPLES section 4), and `move-if-change' hides it,
# so the first thing checked is that the emitted line is actually in the
# emitted file -- not that genpreds ran.
#
# ARM 5 is the injection and costs a rebuild, so it runs last and always
# restores.  It requires the OLD ANSWER BACK BY VALUE, not merely a failure.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b128}
G="$SRC/gcc"
CC1=$B/gcc/cc1
TC=$B/gcc/../lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
TCX=$B/gcc/../lib/gcc/17.0.0/x86_64-pc-linux-gnu/specs-config
pass=0; fail=0
ok  () { pass=$((pass+1)); echo "PASS  $*"; }
bad () { fail=$((fail+1)); echo "FAIL  $*"; }
have () { grep -F -- "$2" "$1" > /dev/null 2>&1; }

echo "===== ARM 0 -- the GENERATED artefacts, by name and by value"
# The shared header must carry the include; a per-base one must NOT.
if have "$B/gcc/tm-preds.h" '#include "multi-target-preds.h"'; then
  ok "build-root tm-preds.h includes multi-target-preds.h"
else
  bad "build-root tm-preds.h does NOT include multi-target-preds.h -- genpreds ran and changed nothing"
fi
for base in i386 aarch64; do
  if [ ! -f "$B/gcc/tm-preds-$base.h" ]; then
    bad "tm-preds-$base.h missing -- arm is vacuous"
  elif have "$B/gcc/tm-preds-$base.h" '#include "multi-target-preds.h"'; then
    bad "tm-preds-$base.h includes multi-target-preds.h -- a back end must keep its OWN wrappers"
  else
    ok "tm-preds-$base.h correctly does NOT include multi-target-preds.h"
  fi
done
# And the companion opt-out, without which insn-preds.cc would rename its own
# DEFINITIONS of insn_const_int_ok_for_constraint / eval_dependent_filter.
if have "$B/gcc/insn-preds.cc" '#define MULTI_TARGET_PREDS_NO_REDIRECT 1'; then
  ok "un-namespaced insn-preds.cc opts out of the redirect"
else
  bad "insn-preds.cc has no MULTI_TARGET_PREDS_NO_REDIRECT"
fi
for base in i386 aarch64; do
  f="$B/gcc/mt-$base/insn-preds-$base.cc"
  if [ ! -f "$f" ]; then bad "$f missing -- arm is vacuous"
  elif have "$f" 'MULTI_TARGET_PREDS_NO_REDIRECT'; then
    bad "insn-preds-$base.cc carries the opt-out it must not need"
  else ok "insn-preds-$base.cc has no opt-out (correct: it never sees the header)"; fi
done

echo "===== ARM 1 -- the redirect names every entry point, and nothing else"
for n in lookup_constraint constraint_satisfied_p reg_class_for_constraint \
         get_constraint_type insn_extra_register_constraint \
         insn_extra_memory_constraint insn_extra_special_memory_constraint \
         insn_extra_relaxed_memory_constraint insn_extra_address_constraint \
         insn_extra_constraint_allows_reg_mem insn_constraint_len \
         insn_const_int_ok_for_constraint get_register_filter \
         get_register_filter_id get_dependent_filter_id \
         get_dependent_filter_ref eval_dependent_filter CONSTRAINT_X; do
  if have "$G/multi-target-preds.h" "#undef $n" \
     && have "$G/multi-target-preds.h" "#define $n"; then
    ok "multi-target-preds.h has BOTH halves for $n"
  else
    bad "multi-target-preds.h is missing a half for $n"
  fi
done
# CONSTRAINT__UNKNOWN must NOT be redirected: it is 0 in every back end and is
# the one value that means the same thing in all of them.
if have "$G/multi-target-preds.h" "#define CONSTRAINT__UNKNOWN"; then
  bad "CONSTRAINT__UNKNOWN is redirected -- it is 0 everywhere and must stay a constant"
else
  ok "CONSTRAINT__UNKNOWN is left alone (0 in every back end)"
fi

echo "===== ARM 2 -- the thunks are DEFINED and INSTALLED, not merely compiled"
for f in lookup_constraint constraint_satisfied_p reg_class_for_constraint \
         get_constraint_type insn_extra_register_constraint \
         insn_extra_memory_constraint insn_extra_special_memory_constraint \
         insn_extra_relaxed_memory_constraint insn_extra_address_constraint \
         insn_extra_constraint_allows_reg_mem insn_constraint_len \
         insn_const_int_ok_for_constraint get_register_filter \
         get_register_filter_id get_dependent_filter_id \
         get_dependent_filter_ref eval_dependent_filter; do
  if grep -E "^mt_base_$f \(" "$G/target-cumargs.cc" > /dev/null 2>&1; then
    d=1; else d=0; fi
  if grep -E "^  mt_base_$f,?\$" "$G/target-cumargs.cc" > /dev/null 2>&1; then
    i=1; else i=0; fi
  if [ "$d" = 1 ] && [ "$i" = 1 ]; then
    ok "mt_base_$f is defined AND installed in mt_base_preds"
  elif [ "$d" = 1 ]; then
    bad "mt_base_$f is DEFINED BUT NOT INSTALLED -- a mechanism nothing invokes"
  else
    bad "mt_base_$f is not defined"
  fi
done
if grep -E '^  &mt_base_preds$' "$G/target-cumargs.cc" > /dev/null 2>&1; then
  ok "mt_base_preds is attached to the cumargs table"
else
  bad "mt_base_preds is not attached to the cumargs table"
fi
if have "$G/multi-target-select.cc" 'targetm_preds = targetm_cumargs->preds;'; then
  ok "multi_target_select installs targetm_preds"
else
  bad "NOTHING INSTALLS targetm_preds -- the table would stay NULL"
fi

echo "===== ARM 3 -- shared objects bind the FORWARDER, not the primary's copy"
SH="cd $B/gcc && nm -uC"
for o in recog.o lra-constraints.o ira.o stmt.o; do
  if [ ! -f "$B/gcc/$o" ]; then bad "$o missing -- arm is vacuous"; continue; fi
  n=$(sh "$S/eb-shell.sh" "$SH $o" | wc -l)
  if [ "$n" -lt 5 ]; then bad "nm produced $n lines for $o -- arm is vacuous"; continue; fi
  if sh "$S/eb-shell.sh" "$SH $o" | grep -q 'mt_lookup_constraint\|mt_insn_constraint_len\|mt_reg_class_for_constraint\|mt_get_dependent_filter_id\|mt_insn_extra_constraint_allows_reg_mem'; then
    ok "$o binds an mt_* constraint forwarder"
  else
    bad "$o binds NO mt_* forwarder -- the redirect did not reach it"
  fi
  if sh "$S/eb-shell.sh" "$SH $o" | grep -qE '^ *U (lookup_constraint_1|reg_class_for_constraint_1)'; then
    bad "$o STILL binds the primary's un-namespaced $o constraint symbols"
  else
    ok "$o no longer binds lookup_constraint_1 / reg_class_for_constraint_1"
  fi
done

echo "===== ARM 4 -- THE DIVERGENCE, in the running cc1, both sides"
# One breakpoint per run is not needed here: no breakpoint is used at all.
# The reading is taken from the compiler's own behaviour instead -- see
# t128-cause.sh for the gdb arm.  This arm asserts the two bases disagree,
# which is what "everyone now gets the same new answer" cannot produce.
printf 'int g (int a) { return a + 1; }\n' > "$B/guard-fn.c"
for pair in "aarch64:$TC:-mlittle-endian -mabi=lp64" "x86_64:$TCX:"; do
  cpu=${pair%%:*}; rest=${pair#*:}; tc=${rest%%:*}; extra=${rest#*:}
  if [ ! -f "$tc" ]; then bad "$cpu specs-config missing -- arm is vacuous"; fi
done
cat > "$B/gdb-g.cmd" <<EOF
set confirm off
set pagination off
break multi_target_select
run
finish
p ((int (*)(const char *)) _Z20mt_lookup_constraintPKc) ("k")
p ((int (*)(int)) _Z27mt_reg_class_for_constrainti) (((int (*)(const char *)) _Z20mt_lookup_constraintPKc) ("k"))
p ((int (*)(void)) _Z15mt_constraint_Xv) ()
quit
EOF
run_read () {   # run_read <tag> <extra args> <target-config>
  sh "$S/eb-shell-gdb.sh" "gdb -batch -x $B/gdb-g.cmd --args $CC1 -quiet -nostdinc \
    $B/guard-fn.c $2 -ftarget-config=$3 -o $B/guard-$1.s" > "$B/guard-$1.out" 2>&1
  grep -E '^\$[0-9]+ = ' "$B/guard-$1.out" | sed 's/^[^=]*= //' | tr '\n' ' '
}
A=$(run_read a64 "-mlittle-endian -mabi=lp64" "$TC")
X=$(run_read x86 "" "$TCX")
echo "  aarch64: k, reg_class(k), CONSTRAINT_X = $A"
echo "  x86_64 : k, reg_class(k), CONSTRAINT_X = $X"
if [ -z "$A" ] || [ -z "$X" ]; then
  bad "one side read NOTHING -- an all-empty read is indistinguishable from agreement"
elif [ "$A" = "$X" ]; then
  bad "both bases answer the SAME -- either the selector is not wired or everyone got one new answer"
else
  ok "the two bases diverge on every reading (aarch64 '$A' vs x86_64 '$X')"
fi
# And by VALUE, not merely by difference: aarch64's `k' is its STACK_REG,
# which is reg class 6 in aarch64.h's REG_CLASS_NAMES (0 NO_REGS, 1
# W8_W11_REGS, 2 W12_W15_REGS, 3 TAILCALL_ADDR_REGS, 4 STUB_REGS, 5
# GENERAL_REGS, 6 STACK_REG).  i386's `k' is
# `TARGET_AVX512F ? ALL_MASK_REGS : NO_REGS' and answers 0.
case "$A" in
  "2 6 "*) ok "aarch64 k = 2 and reg_class = 6 (STACK_REG), by value" ;;
  *)       bad "aarch64 k/reg_class is '$A', expected '2 6 ...'" ;;
esac
case "$X" in
  "18 0 "*) ok "x86_64 k = 18 and reg_class = 0 (NO_REGS), by value -- i386 still gets i386's" ;;
  *)        bad "x86_64 k/reg_class is '$X', expected '18 0 ...'" ;;
esac

echo "===== ARM 5 -- THE INJECTION (rebuilds; always restores)"
# Remove ONLY the genpreds line that emits the include.  Everything else --
# the thunks, the table, the selector, multi-target-preds.h -- stays compiled,
# so this isolates the redirect itself and not the machinery behind it.
# It must bring back the OLD ANSWER BY VALUE (aarch64 k = 18, i386's), which
# is stronger than requiring any failure at all.
INJ="$G/genpreds.cc"
cp "$INJ" "$B/genpreds.cc.orig" || { bad "cannot save genpreds.cc"; }
# BOTH LINES OF THE HUNK, and this is not fastidiousness.  Deleting only the
# `puts' left the `if' attached to the NEXT statement -- the one emitting
# `#endif /* tm-preds.h */' -- so every PER-BASE header came out unterminated
# and the build died in tm-preds-i386.h.  The injection then read the OLD,
# FIXED cc1 and would have scored as "the bug did not come back".  #125 and
# #126 each recorded a half-removed hunk producing a third state nobody was
# testing; this is the same failure in a new shape.
awk 'BEGIN { prev = ""; have = 0 }
     {
       if (have) {
	 if (prev ~ /gen_target_ns \(\) == NULL/ && $0 ~ /multi-target-preds\.h/)
	   { have = 0; next }
	 print prev
       }
       prev = $0; have = 1
     }
     END { if (have) print prev }' "$B/genpreds.cc.orig" > "$INJ"
nif=$(grep -c 'gen_target_ns () == NULL' "$INJ")
if grep -F 'multi-target-preds.h' "$INJ" | grep -F 'puts' > /dev/null 2>&1 \
   || [ "$nif" != 1 ]; then
  bad "INJECTION DID NOT FIRE (puts still present, or $nif 'gen_target_ns () == NULL' lines left instead of 1) -- every reading below is of the FIXED compiler"
  cp "$B/genpreds.cc.orig" "$INJ"
else
  ok "injection removed BOTH lines of the emit hunk from genpreds.cc"
  sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 multi-target-objs cc1" \
    > "$B/inj.out" 2> "$B/inj.err"
  irc=$?
  echo "  injected build rc=$irc"
  if [ "$irc" != 0 ]; then
    bad "INJECTED BUILD FAILED (rc=$irc) -- cc1 was not relinked, so the reading below is of the OLD binary: $(grep -m1 'error:' "$B/inj.err")"
  else
    ok "injected build succeeded, so cc1 really is the injected one"
  fi
  if have "$B/gcc/tm-preds.h" '#include "multi-target-preds.h"'; then
    bad "tm-preds.h STILL has the include after the injected build -- it did not regenerate"
  else
    ok "tm-preds.h lost the include (the artefact changed, not just the source)"
  fi
  # WHAT THE INJECTION ACTUALLY CONTROLS, and the first version of this arm
  # got it wrong in the direction that passes.  It re-read
  # `mt_lookup_constraint' through gdb -- but that forwarder is still
  # compiled and still correct in the injected compiler; the injection
  # removes the RENAMING of shared code's call sites, not the table.  So the
  # arm was asking a question whose answer the injection cannot change, and
  # any value it liked would have been a false green.
  #
  # The observable is which symbol `recog.o' binds.
  inj_syms=$(sh "$S/eb-shell.sh" "cd $B/gcc && nm -uC recog.o")
  if [ -z "$inj_syms" ]; then
    bad "nm read nothing from the injected recog.o -- arm is vacuous"
  else
    if echo "$inj_syms" | grep -qE '^ *U (lookup_constraint_1|reg_class_for_constraint_1)'; then
      ok "INJECTION REPRODUCES THE BUG BY NAME: recog.o binds the primary's lookup_constraint_1 / reg_class_for_constraint_1 again"
    else
      bad "injected recog.o does NOT bind the primary's constraint symbols -- the injection did not take"
    fi
    if echo "$inj_syms" | grep -q 'mt_lookup_constraint'; then
      bad "injected recog.o still binds mt_lookup_constraint -- the redirect survived"
    else
      ok "injected recog.o no longer binds any mt_* constraint forwarder"
    fi
  fi
  # AND WHAT THIS ARM CANNOT SHOW, said rather than skipped: the user-visible
  # aarch64 failure is IDENTICAL either way, because the next leak
  # (`get_attr_enabled' from the primary's insn-attrtab.o; see STATE.md)
  # stops the same input at the same line.  A behavioural assertion here
  # would be vacuous, so this arm is a symbol-level one and says so.
  AI=$(run_read a64inj "-mlittle-endian -mabi=lp64" "$TC")
  echo "  injected table reading (unchanged BY DESIGN, the tables are not injected): $AI"
  cp "$B/genpreds.cc.orig" "$INJ"
  if grep -F 'multi-target-preds.h' "$INJ" | grep -F 'puts' > /dev/null 2>&1; then
    ok "genpreds.cc restored"
  else
    bad "RESTORE FAILED -- genpreds.cc is still injected"
  fi
  sh "$S/eb-shell.sh" "cd $B/gcc && make -j8 multi-target-objs cc1" \
    > "$B/res.out" 2> "$B/res.err"
  echo "  restored build rc=$?"
  AR=$(run_read a64res "-mlittle-endian -mabi=lp64" "$TC")
  if [ "$AR" = "$A" ]; then
    ok "restored reading matches the pre-injection one ($AR)"
  else
    bad "restored reading '$AR' != pre-injection '$A'"
  fi
fi

echo "===== $pass PASS / $fail FAIL"
[ "$fail" = 0 ]
