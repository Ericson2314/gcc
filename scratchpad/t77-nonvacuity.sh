#!/bin/sh
# Non-vacuity: regenerate options-save.cc from THIS build dir's own optionlist
# and union list, with the pre-change awk (n_opts/flags[]) and the post-change
# awk (n_sv/sv_flags[]), and diff the cl_optimization_compare body.
set -e
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-af7e06a12bc211827
B=/tmp/b-77t/gcc
O=/tmp/t77-nv
rm -rf $O; mkdir -p $O

[ -s $B/optionlist ] || { echo "FATAL: no optionlist"; exit 9; }
[ -s $B/gcc-options-union.list ] || { echo "FATAL: no union list"; exit 9; }
echo "union list bases: $(grep -c '^base ' $B/gcc-options-union.list)"
grep '^base ' $B/gcc-options-union.list

# The pre-change script: revert exactly the hunk under test.
git -C $W show HEAD:gcc/optc-save-gen.awk > $O/optc-save-gen.before.awk
cp $W/gcc/optc-save-gen.awk $O/optc-save-gen.after.awk
cmp -s $O/optc-save-gen.before.awk $O/optc-save-gen.after.awk && {
  echo "FATAL: before and after scripts are identical -- nothing under test"; exit 9; }

for v in before after; do
  awk -f $W/gcc/opt-functions.awk -f $W/gcc/opt-read.awk \
      -v union_file=$B/gcc-options-union.list -v union_base=i386 \
      -f $O/optc-save-gen.$v.awk \
      -v header_name="config.h system.h coretypes.h tm.h" \
      < $B/optionlist > $O/options-save.$v.cc 2> $O/gen.$v.err
  [ -s $O/options-save.$v.cc ] || { echo "FATAL: $v generated nothing"; cat $O/gen.$v.err; exit 9; }
done

echo "--- total lines: before $(wc -l < $O/options-save.before.cc)  after $(wc -l < $O/options-save.after.cc)"

for v in before after; do
  sed -n '/^cl_optimization_compare/,/^}/p' $O/options-save.$v.cc > $O/cmp.$v
  [ -s $O/cmp.$v ] || { echo "FATAL: could not extract cl_optimization_compare ($v)"; exit 9; }
  echo "cl_optimization_compare $v: $(grep -c 'ptr1->' $O/cmp.$v) comparisons, $(grep -c aarch64 $O/cmp.$v) naming an aarch64 member"
done

echo "--- the ONLY function that changed:"
diff $O/options-save.before.cc $O/options-save.after.cc > $O/full.diff || true
[ -s $O/full.diff ] || { echo "FATAL: artefacts identical -- the change is vacuous"; exit 9; }
echo "diff lines: $(wc -l < $O/full.diff)"
echo "added lines all inside cl_optimization_compare? checking:"
grep '^>' $O/full.diff | sed 's/^> //' | grep -v 'ptr1->\|ptr2->\|internal_error\|^ *&&\|^ *||' | head

echo "--- sample of newly-compared aarch64 members:"
grep '^>' $O/full.diff | grep -o 'x_aarch64_[a-z_0-9]*' | sort -u | head -20

echo "--- single-target byte-identity (no union list): must be IDENTICAL"
for v in before after; do
  awk -f $W/gcc/opt-functions.awk -f $W/gcc/opt-read.awk \
      -f $O/optc-save-gen.$v.awk \
      -v header_name="config.h system.h coretypes.h tm.h" \
      < $B/optionlist > $O/st.$v.cc 2>> $O/gen.$v.err
  [ -s $O/st.$v.cc ] || { echo "FATAL: single-target $v generated nothing"; exit 9; }
done
if cmp -s $O/st.before.cc $O/st.after.cc; then
  echo "single-target: IDENTICAL ($(wc -l < $O/st.after.cc) lines)"
else
  echo "FATAL: single-target output changed"; diff $O/st.before.cc $O/st.after.cc | head -20; exit 1
fi
echo OK
