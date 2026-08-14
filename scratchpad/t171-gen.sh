#!/bin/sh
# #171 -- make just the generated pass artefacts in a build dir, so a defect in
# the two new generators shows up in seconds rather than at the end of a cc1
# build.  $1 = build dir.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
case "$D" in
  */b-a0e5*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
sh "$S/eb-shell.sh" "cd $D/gcc && make multi-target-md.mk multi-target-passes.h pass-instances.def" \
  > "$D/gen.out" 2> "$D/gen.err"
echo "rc=$?"
tail -20 "$D/gen.err"
echo "== MT_PASSES_TAGS in multi-target-md.mk"
grep 'MT_PASSES_TAGS' "$D/gcc/multi-target-md.mk" || echo "  (none)"
echo "== target-pass lines in pass-instances.def"
grep -cE 'NEXT_PASS[A-Z_]* \(pass_[A-Za-z0-9_]*_mt_' "$D/gcc/pass-instances.def" 2>/dev/null \
  || echo "  (no pass-instances.def)"
