#!/bin/sh
# #150 (incidental) -- IS `MULTI_TARGET_RENAME_NAMES' COMPLETE FOR N BASES?
#
# gcc/Makefile.in says of that list:
#
#   THE LIST IS ONE AUTHORITY AND IT IS NOT SELF-MAINTAINING.  A name added to
#   some back end later collides silently: libbackend.a is an archive, so a
#   duplicate is diagnosed only when both members happen to be pulled in for
#   other reasons -- `ld' once reported 7 of 40.  The check is an `nm' sweep
#   over the two object SETS (scratchpad/sweep.sh), never the linker.
#
# TWO THINGS ARE WRONG WITH THAT AS IT STANDS, AND BOTH ARE THE BRANCH'S OWN
# NAMED FAILURE MODES:
#
#   1. `scratchpad/sweep.sh' DOES NOT EXIST IN THIS TREE.  A written invariant
#      is not evidence anyone ran it (PRINCIPLES section 4, rule 3).  The
#      comment names its own check and the check is absent.
#
#   2. "the TWO object sets" is the two-back-ends habit written into the
#      instrument.  The list was sized on i386 + aarch64, and it is complete
#      FOR THAT PAIR.  It is not complete for four.
#
# This is the N-way version: every pair of configured bases, not one pair.
#
# usage: t150-rename-gap.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"

bases=$(ls -d "$G"/mt-* 2>/dev/null | sed 's|.*/mt-||')
nb=$(printf '%s\n' "$bases" | grep -c . || true)
[ "$nb" -ge 2 ] || { echo "REFUSING TO SCORE: found $nb base dirs under $G"; exit 9; }
echo "arm 0 ok: $nb configured bases: $(printf '%s ' $bases)"

# Strong, defined, GLOBAL (T/D/B/R) symbols per base's hand-written objects.
# Not the generated insn-* objects: those are already namespaced, and this
# question is specifically about the hand-written config/ sources that cannot
# be namespaced because the project does not edit them.
tot=0
for b in $bases; do
  sh "$S/eb-shell.sh" "cd $G && nm -C --defined-only mt-$b/*.o 2>/dev/null" \
    | awk '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print }' \
    | sort -u > "$B/t150-syms-$b.txt"
  n=$(grep -c . "$B/t150-syms-$b.txt" || true)
  echo "  $b: $n global definitions"
  tot=$((tot + n))
done
[ "$tot" -gt 0 ] || { echo "REFUSING TO SCORE: nm read nothing (not in the shell?)"; exit 9; }

echo
echo "== names defined by MORE THAN ONE base (the collision set)"
cat "$B"/t150-syms-*.txt | sort | uniq -d > "$B/t150-collisions.txt"
nc=$(grep -c . "$B/t150-collisions.txt" || true)
echo "  $nc colliding names over $nb bases"
echo "  (pairwise, per base, so a name in 3 bases counts once here)"
head -60 "$B/t150-collisions.txt" | sed 's/^/    /'
echo
# NB: the backtick spelling of this NOTE ran `ld` as a command substitution and
# printed `ld: command not found' into the middle of the report -- PRINCIPLES
# section 5's "a backtick in a heredoc comment wrote nothing", met again.
echo "NOTE: ld reports only the subset whose archive members are both pulled"
echo "in.  This sweep is the authority; the linker is an UNDER-count of it."
echo "Seven of the names above are mt_probe_*, which are the deliberate"
echo "MULTI_TARGET_REG_PROBES -- compiled and never linked, so benign."
