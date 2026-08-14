#!/bin/sh
# #171 -- the EIGHT-BASE arm: the ordering trap, and cc1 actually starting.
#
# The eight-base set is where aarch64 and arm are BOTH configured, so it is the
# only one that exercises the trap the brief names: `make_pass_insert_bti' is
# defined bare by both back ends and is in MULTI_TARGET_RENAME_NAMES, and
# before this change the rename was safe only because the pass was absent from
# pass-instances.def.
#
# TWO ARMS, BECAUSE `IT LINKS' IS NOT `IT RUNS'.  pass_manager is constructed
# in general_init, BEFORE any target is selected, so every configured back
# end's pass factory is called on every invocation.  A duplicate dump-file
# name, a null factory, an assert in add_pass_instance -- none of those is a
# link error and all of them ICE at startup for every compilation.  So the
# second arm invokes the compiler and requires it to reach the target-selection
# diagnostic, which is downstream of pass_manager's constructor.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-a0e5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D has no make-top.rc stamp; refusing"; \
  echo "  to score a log that may still be being written."; exit 9; }
echo "build stamp rc=$(cat "$D/make-top.rc")"

echo
echo "== ARM 1 -- both back ends' pass_insert_bti in ONE pass-instances.def"
grep -nE 'NEXT_PASS[A-Z_]* \(pass_insert_bti' "$D/gcc/pass-instances.def" | sed 's/^/  /'
n=$(grep -cE 'NEXT_PASS[A-Z_]* \(pass_insert_bti' "$D/gcc/pass-instances.def" || true)
[ "$n" = 2 ] || { echo "  FATAL: expected exactly 2, got $n."; exit 9; }
echo "  and the two forwarders that make them distinct symbols:"
grep -n 'insert_bti' "$D/gcc/multi-target-passes.h" | sed 's/^/  /'
echo "  defined in:"
for b in aarch64 arm; do
  echo "    mt-$b/target-passes-$b.cc: $(grep -c '^make_' "$D/gcc/mt-$b/target-passes-$b.cc") forwarder(s)"
done
echo "  and in the linked cc1, as two distinct symbols:"
sh "$S/eb-shell.sh" "nm -C '$D/gcc/cc1' | grep -w 'make_pass_insert_bti_mt_aarch64\|make_pass_insert_bti_mt_arm\|make_pass_insert_bti_aarch64\|make_pass_insert_bti_arm'" \
  | sed 's/^/    /'

echo
echo "== ARM 2 -- cc1 STARTS.  pass_manager is built before any target is"
echo "   selected, so every back end's factory runs on every invocation."
echo 'int main (void) { return 0; }' > "$D/mt-startup.c"
sh "$S/eb-shell.sh" "cd $D/gcc && ./cc1 -quiet -nostdinc \
  -ftarget-config=/nonexistent-on-purpose $D/mt-startup.c -o $D/mt-startup.s" \
  > "$D/startup.out" 2> "$D/startup.err"
echo "  rc=$?"
sed 's/^/    /' "$D/startup.err" | head -5
# The diagnostic it must reach is DOWNSTREAM of pass_manager's constructor.
# An ICE, a `Segmentation fault' or an assertion here is the failure this arm
# exists to catch, and each of those is a DIFFERENT message -- so the check is
# for the expected one by name, not for the absence of a bad one.
#
# THE EXPECTED FAILURE IS AN `internal_error', so `grep -q "internal compiler
# error"' is the WRONG check and its first draft scored this arm FATAL on a
# correct compiler.  With no target-config there is no target, and this branch
# refuses by name -- `no target configuration was selected, so there is no
# register vocabulary to initialise' -- which is init_reg_sets doing its job.
# What matters is only that cc1 got THAT far: init_reg_sets runs in
# toplev::main, well after general_init built the pass manager.  So match the
# expected message exactly and treat any OTHER ICE as the failure.
if grep -q 'no target configuration was selected' "$D/startup.err"; then
  echo "  reached init_reg_sets, i.e. past general_init: pass_manager"
  echo "  constructed every configured back end's forwarders without crashing."
elif grep -qi 'internal compiler error\|Segmentation fault\|Assertion' "$D/startup.err"; then
  echo "  FATAL: cc1 failed with an ICE that is NOT the expected no-target one."
  exit 9
else
  echo "  FATAL: cc1 did not produce the expected no-target diagnostic at all."
  exit 9
fi

echo
echo "== ARM 3 -- per-back-end pass census in this build"
for b in i386 aarch64 arm rs6000 s390 riscv sparc mips; do
  c=$(grep -cE "NEXT_PASS[A-Z_]* \(pass_[A-Za-z0-9_]*_mt_$b," "$D/gcc/pass-instances.def" || true)
  f=0
  [ -f "$D/gcc/mt-$b/target-passes-$b.cc" ] \
    && f=$(grep -c '^make_' "$D/gcc/mt-$b/target-passes-$b.cc")
  printf "  %-8s %2d NEXT_PASS lines, %2d forwarders\n" "$b" "$c" "$f"
done
echo "  (mips has no <cpu>-passes.def in tree; 0/0 is correct, not a gap.)"
