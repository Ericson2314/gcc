#!/bin/sh
# #172 -- run target-specs/configure for the three configured targets, each
# against ITS OWN real cross binutils (t170-tools.sh has already proved every
# linked `as' assembles for the machine it claims).
# usage: t172-specs.sh <builddir> <toolroot>
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
ROOT=${2:?tool root}
case "$D" in
  */b-a82dcce59b2d6b84e*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/gcc/multi-target.manifest" ] || { echo "FATAL: no manifest"; exit 9; }
rc=0
for t in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  sh "$S/eb-shell.sh" \
    "cd $D && make configure-target-specs-$t TOOLS_DIR_FOR_$t=$ROOT/$t" \
    > "$D/spec-$t.out" 2> "$D/spec-$t.err"
  r=$?
  echo "$t rc=$r"
  [ "$r" = 0 ] || { rc=1; tail -5 "$D/spec-$t.err"; }
done
echo "== *option_defaults, per target (the line this task is about)"
for t in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  f=$(ls "$D"/lib/gcc/*/"$t"/specs 2>/dev/null | head -1)
  [ -n "$f" ] || { echo "  $t: NO SPEC FILE"; rc=1; continue; }
  printf '  %-28s %s\n' "$t" "$(awk '/^\*option_defaults:/{getline; print; exit}' "$f")"
done
exit $rc
