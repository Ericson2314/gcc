#!/bin/sh
# #171 -- does putting every back end's target passes in ONE pass tree collide
# in the DUMP-FILE vocabulary?
#
# `register_one_dump_file' (passes.cc) builds the dump switch from `pass->name'
# -- not from the pass-instances.def name -- so `pass_insert_bti_mt_aarch64'
# and `pass_insert_bti_mt_arm' both register `rtl-bti'.  The renaming this task
# did is in the C++ symbol namespace and does not reach the pass's own `name'
# field, which lives in its `pass_data'.
#
# This arm asks the RUNNING compiler which switches it registered and counts
# duplicates.  It is the same shape as the defect this whole branch is about --
# one name, several authorities -- arriving in the diagnostic surface rather
# than in codegen, so it is measured and reported rather than guessed at.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
T=${2:-aarch64-unknown-linux-gnu}
case "$D" in
  */b-a0e5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
CFG=$D/lib/gcc/17.0.0/$T/specs-config
[ -f "$CFG" ] || { echo "FATAL: no $CFG"; exit 9; }
echo 'int f (int a) { return a + 1; }' > "$D/dn.c"
sh "$S/eb-shell.sh" "cd $D/gcc && ./cc1 -quiet -nostdinc -ftarget-config=$CFG \
  -O2 -fdump-passes $D/dn.c -o $D/dn.s" > "$D/dn.out" 2> "$D/dn.err"
echo "rc=$?  ($T)"
n=$(grep -c ':' "$D/dn.err" || true)
[ "$n" -gt 100 ] || { echo "FATAL: -fdump-passes listed only $n passes; the"; \
  echo "  compiler did not get far enough for this to mean anything."; exit 9; }
echo "passes listed: $n"

echo
echo "== target passes, and whether they are ON for $T"
grep -E '(stv|vzeroupper|apxnf|x86_cse|rpad|endbr|align_tight|bti|early_ra|fma_steering|speculation|ldp_fusion|narrow_gp|pstate|vsetvl|rvv|swap|analyze_swaps|s390|sparc|zbb)' \
  "$D/dn.err" | sed 's/^ */  /' | sort -u

echo
echo "== DUPLICATE dump switches (one name, several passes)"
awk -F: '{ s=$1; gsub(/^[ \t]+|[ \t]+$/, "", s); if (s != "") print s }' "$D/dn.err" \
  | sort | uniq -d | sed 's/^/  /'
d=$(awk -F: '{ s=$1; gsub(/^[ \t]+|[ \t]+$/, "", s); if (s != "") print s }' "$D/dn.err" \
  | sort | uniq -d | wc -l)
echo "  $d duplicated switch name(s)"
